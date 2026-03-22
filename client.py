import eel
import logging
import sys
import json
import os
import gevent
from gevent import monkey

monkey.patch_all()

from backend import Backend, SecurityError
from indexer import PrismIndexer
from core.settings import sys_config
from sensor_mocks import MockFingerSensor

CLIENT_CONFIG_PATH = "config.json"
DEVICE_LOCK_ENABLED = True

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("CLIENT")

import os
base_dir=os.path.dirname(os.path.abspath(__file__))
eel.init(os.path.join(base_dir, 'web-react/dist'))

system = None
indexer = None
indexer_thread = None

def background_indexer_sync():
    logger.info(" Background Indexer Sync Loop Active")
    while True:
        if indexer:
            try:
                indexer.run_sync()
            except Exception as e:
                logger.error(f"Indexer sync failed: {e}")
        gevent.sleep(10)

def load_owner():
    if os.path.exists(CLIENT_CONFIG_PATH):
        try:
            with open(CLIENT_CONFIG_PATH, 'r') as f:
                data = json.load(f)
            if 'address' not in data and 'owner_did' in data:
                data['address'] = data['owner_did']
            return data
        except Exception as e:
            logger.error(f"Failed to load owner config: {e}")
    return None

def save_owner(user_data):
    """Save owner details to config.json, preserving the owner_key if it exists."""
    os.makedirs(os.path.dirname(CLIENT_CONFIG_PATH), exist_ok=True)
    
    config = {}
    if os.path.exists(CLIENT_CONFIG_PATH):
        try:
            with open(CLIENT_CONFIG_PATH, 'r') as f:
                config = json.load(f)
        except Exception as e:
            logger.warning(f"Could not read existing config for merge: {e}")
            
    config.update(user_data)
    
    with open(CLIENT_CONFIG_PATH, 'w') as f:
        json.dump(config, f, indent=2)
    logger.info(f"Device bound to: {user_data.get('user_id', 'Unknown')}")

def unbind_device():
    """Admin function to unbind device from current owner."""
    if os.path.exists(CLIENT_CONFIG_PATH):
        os.remove(CLIENT_CONFIG_PATH)
        logger.warning("[WARN] Device unbound from owner")
        return True
    return False

@eel.expose
def init_system():
    global system, indexer, indexer_thread
    try:
        logger.info("Initializing Personal Client System...")
        if not system:
            ui_test_mode = os.environ.get('UI_TEST_MODE', '').lower() in ('1', 'true', 'yes') or \
                           os.environ.get('UI_MODE_TEST', '').lower() in ('1', 'true', 'yes')
            if ui_test_mode:
                logger.warning(" Running in UI_TEST_MODE. Injecting MockFingerSensor.")
                system = Backend(finger_sensor=MockFingerSensor(), require_hardware=False)
            else:
                system = Backend(require_hardware=False)
            indexer = PrismIndexer()
            
            if not indexer_thread:
                indexer_thread = gevent.spawn(background_indexer_sync)
                logger.info(" Background indexer sync auto-started.")
        
        caps = system.get_capabilities()
        if not caps['canRecord']:
            logger.warning("[WARN] DEVICE NOT AUTHORIZED. Please ask Admin to whitelist this device address.")
            return {"status": "warning", "message": "Device not authorized to record attendance."}

        return {"status": "ok", "message": "Client System Initialized"}
    except Exception as e:
        logger.error(f"Init failed: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def get_system_capabilities():
    """Returns dynamic capabilities from the blockchain."""
    if system:
        return system.get_capabilities()
    return {"canEnroll": False, "canRecord": False, "canRevoke": False}

@eel.expose
def get_device_address():
    if system:
        return system.get_device_address()
    return "Unknown"

@eel.expose
def check_health():
    """Check system health for reconnection handling."""
    if not system or not system.agent:
        return {"status": "error", "message": "System not initialized"}
    if not system.agent.w3:
        return {"status": "error", "message": "Blockchain not connected"}
    try:
        if not system.agent.w3.is_connected():
            return {"status": "error", "message": "RPC disconnected"}
        return {
            "status": "ok", 
            "node": system.agent.current_rpc_node,
            "block": system.agent.w3.eth.block_number
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def get_local_owner():
    """Returns the bound user of this device (if any)."""
    return load_owner()

@eel.expose
def verify(user_input=None):
    global system, indexer
    if not system: return {"status": "error", "message": "System not initialized"}
    
    try:
        target_addr = None
        
        if not user_input:
            owner = load_owner()
            if owner:
                target_addr = owner.get('address')
                if not target_addr and owner.get('owner_did'):
                    target_addr = owner.get('owner_did').split(':')[-1]
                
                user_id = owner.get('user_id')
                
                if target_addr and not user_id:
                    res = indexer.conn.cursor().execute("SELECT user_id FROM users WHERE LOWER(address) = LOWER(?)", (target_addr,)).fetchone()
                    if res:
                        user_id = res[0]
                
                if user_id:
                    logger.info(f"Using local owner for verification: {user_id} ({target_addr})")
                else:
                    logger.info(f"Using local owner address: {target_addr}")
        
        if not target_addr and user_input:
            target_addr = indexer.lookup_user(user_input)
            if not target_addr:
                 return {"status": "error", "message": f"User '{user_input}' not found."}
             
        user_id = None
        res = indexer.conn.cursor().execute("SELECT user_id FROM users WHERE LOWER(address) = LOWER(?)", (target_addr,)).fetchone()
        if res:
            user_id = res[0]
                
        if not user_id:
             return {"status": "error", "message": "Could not resolve user_id for fingerprint mock."}
        
        owner = load_owner()
        if DEVICE_LOCK_ENABLED and owner:
            if owner.get('address') and target_addr.lower() != owner.get('address').lower():
                 logger.warning(f"Device Lock: Rejected {target_addr}. Owner is {owner.get('address')}")
                 return {"status": "error", "message": "Device is locked to a different user."}
        
        ui_test_mode = os.environ.get('UI_TEST_MODE', '').lower() in ('1', 'true', 'yes')
        if getattr(system.sensor, 'set_samples', None):
             import glob
             fp_samples = sorted(glob.glob(os.path.join("fingerprint_dataset", user_id, "*.png"))) if user_id else []
             if not fp_samples:
                 logger.warning(f"No fingerprint samples found for {user_id}. Falling back to U001 for test mode.")
                 fp_samples = sorted(glob.glob(os.path.join("fingerprint_dataset", "U001", "*.png")))
                 
             if len(fp_samples) >= 4:
                 logger.info(f"Injecting mock fingerprint sample for {user_id or 'Unknown'}")
                 system.sensor.set_samples(user_addr=target_addr, paths=[fp_samples[3]])
             else:
                 logger.error(f"Not enough fingerprint samples found for mocking.")
                 return {"status": "error", "message": "Missing fingerprint mock data."}
        
        cid = system.verify(target_addr)
        
        if not owner:
            profile_data = system.agent.get_user_profile(system.registry_contract, target_addr)
            if "error" in profile_data:
                logger.error(f"Post-verify profile fetch failed: {profile_data['error']}")
            else:
                profile = profile_data.get('profile', {})
                identity = profile.get('identity', {})
                owner_record = {
                    "user_id": identity.get('user_id', 'Unknown'),
                    "name": identity.get('name', 'Unknown'),
                    "address": target_addr,
                    "did": profile_data.get('did', '')
                }
                save_owner(owner_record)
            
        return {"status": "ok", "message": "Verification Successful", "cid": cid}

    except Exception as e:
        logger.error(f"Verify Error: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def get_my_profile():
    owner = load_owner()
    if not owner: return {"status": "error", "message": "Device not bound to a user."}
    
    global system
    try:
        addr = owner.get('address')
        if not addr and owner.get('owner_did'):
             addr = owner['owner_did'].split(':')[-1]
             
        if not addr: return {"status": "error", "message": "No address bound."}
        
        data = system.agent.get_user_profile(system.registry_contract, addr)
        if "error" in data:
             return {"status": "error", "message": data["error"]}
        return {"status": "ok", "data": data}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def get_my_attendance():
    owner = load_owner()
    if not owner: return {"status": "error", "message": "Device not bound."}
    
    try:
        logs = indexer.get_user_attendance(owner['address'])
        return {"status": "ok", "logs": logs}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def get_my_schedule():
    """Returns the bound user's assigned schedule."""
    owner = load_owner()
    if not owner: return {"status": "error", "message": "Device not bound."}
    
    try:
        schedule = indexer.get_user_schedule(owner['address'])
        return {"status": "ok", "data": schedule}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def get_my_stats():
    """Returns personal attendance statistics including timeliness."""
    owner = load_owner()
    if not owner: return {"status": "error", "message": "Device not bound."}
    
    try:
        stats = indexer.get_user_stats(owner['address'])
        return {"status": "ok", "data": stats}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def get_my_attendance_with_status():
    """Returns attendance history with ON_TIME/LATE/UNSCHEDULED status."""
    owner = load_owner()
    if not owner: return {"status": "error", "message": "Device not bound."}
    
    try:
        import time
        data = indexer.get_attendance_with_status(owner['address'], limit=100)
        result = []
        for a in data:
            ts = a['timestamp']
            result.append({
                "timestamp": ts,
                "date": time.strftime("%Y-%m-%d", time.gmtime(ts)),
                "time": time.strftime("%H:%M", time.gmtime(ts)),
                "expected_time": a['expected_time'] or "-",
                "timeliness": a['timeliness'],
                "status": a['status'] or "SUCCESS",
                "device_id": a['device_id'] or "-"
            })
        return {"status": "ok", "data": result}
    except Exception as e:
        return {"status": "error", "message": str(e)}

def start_app():
    import webbrowser
    try:
        eel.start('user.html', size=(1024, 768), block=True, port=8091)
    except EnvironmentError:
        webbrowser.open('http://localhost:8091/user.html')
        eel.start('user.html', mode=None, host='0.0.0.0', port=8091, block=True)

if __name__ == "__main__":
    start_app()
