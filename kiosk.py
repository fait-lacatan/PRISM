from gevent import monkey
                                                                                  
monkey.patch_all()

import eel
import logging
import sys
import gevent
import threading
import time
import os

from backend import Backend, SecurityError
from indexer import PrismIndexer
from core.settings import sys_config
import instrumentation
try:
    from sensor_mocks import MockFingerSensor
except ImportError:
    MockFingerSensor = None

system = None

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("APP")

eel.init('web-react/dist')

system = None
indexer = None
cached_health = {"status": "loading"}
health_thread = None

def background_health_loop():
    global cached_health, system
    while True:
        if system and not system.busy:
            try:
                                              
                health = system.get_system_health()
                
                health["capabilities"] = system.get_capabilities()
                
                health["last_update"] = time.time()
                health["status"] = "ok"
                cached_health = health
            except Exception as e:
                logger.error(f"Health check failed: {e}")
                cached_health["status"] = "error"
                cached_health["message"] = str(e)
        gevent.sleep(5)                      

def background_indexer_loop():
    global indexer
    logger.info(" Background Indexer Sync Loop Active")
    while True:
        if indexer:
            try:
                indexer.run_sync()
            except Exception as e:
                logger.error(f"Indexer sync failed: {e}")
        gevent.sleep(10)                      

@eel.expose
def init_system():
    global system, indexer, health_thread, indexer_thread
    try:
        logger.info("Initializing Bimodal System...")
        if not system:
            ui_test_mode = os.environ.get('UI_TEST_MODE', '').lower() in ('1', 'true', 'yes') or                           os.environ.get('UI_MODE_TEST', '').lower() in ('1', 'true', 'yes')
            if ui_test_mode:
                logger.warning(" Running in UI_TEST_MODE. Injecting MockFingerSensor.")
                system = Backend(finger_sensor=MockFingerSensor(), require_hardware=False)
            else:
                system = Backend(require_hardware=False)
            
        if not health_thread:
            health_thread = gevent.spawn(background_health_loop)
            logger.info(" Background health monitoring started.")
                
        return {"status": "ok", "message": "System Initialized"}
    except Exception as e:
        logger.error(f"Init failed: {e}")
        return {"status": "error", "message": str(e)}

ui_test_mode = os.environ.get('UI_TEST_MODE', '').lower() in ('1', 'true', 'yes') or               os.environ.get('UI_MODE_TEST', '').lower() in ('1', 'true', 'yes')
if ui_test_mode:
    logger.warning(" Running in UI_TEST_MODE. Injecting MockFingerSensor at module load.")
    system = Backend(finger_sensor=MockFingerSensor(), require_hardware=False)
else:
    system = Backend(require_hardware=False)
    
indexer = PrismIndexer()
indexer_thread = gevent.spawn(background_indexer_loop)
logger.info(" Background indexer sync auto-started.")

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
    """Returns cached health status to keep UI responsive."""
    return cached_health

@eel.expose
def set_sensor_led(state):
    """Bridge for manual LED control."""
    if system and system.sensor:
        system.sensor.set_led(state)
        return True
    return False

@eel.expose
def set_camera_active(state):
    """Bridge for camera buffer management."""
    if system and hasattr(system, '_cam'):
        system._cam.set_active(state)
        return True
    return False

@eel.expose
def check_id_availability(user_id):
    """Checks if a Faculty ID is already registered in the local index."""
    global indexer
    if not indexer:
        return {"status": "error", "message": "Indexer not initialized"}
    
    try:
        addr = indexer.lookup_user(user_id)
        if addr:
            return {"status": "taken", "message": "This ID is already enrolled."}
        return {"status": "available"}
    except Exception as e:
        logger.error(f"Availability check failed: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def check_did_availability(did):
    """Checks if a DID is already registered on-chain."""
    global system
    if not system:
        return {"status": "error", "message": "System not initialized"}
    
    return system.check_did_availability(did)

    return system.check_did_availability(did)

@eel.expose
def cancel_scan():
    """Signals backend to abort current operation."""
    global system
    if system:
        system.cancel()
    return {"status": "ok"}

@eel.expose
def force_reset_system():
    """Hard-resets the backend state and sensor connections."""
    global system
    try:
        if system:
            system.stop()               
                     
            from backend import Backend
            system = Backend(require_hardware=False)
        return {"status": "ok", "message": "System state reset successfully"}
    except Exception as e:
        logger.error(f"Force reset failed: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def scan_did_qr():
    """Triggers the backend QR scanner and returns the detected DID."""
    global system
    if not system:
        return {"status": "error", "message": "System not initialized"}
    
    try:
                                        
        did = system.scan_qr(timeout=30)
        return {"status": "ok", "did": did}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def enroll(user_id, name, target_did, email=None, college=None, department=None, position=None):
    global system, indexer
    if not system: 
        return {"status": "error", "message": "System not initialized"}
    
    try:
                                                                                             
        if indexer:
            addr = indexer.lookup_user(user_id)
            if addr:
                logger.warning(f"Aborting enrollment: Faculty ID {user_id} already indexed to {addr}")
                return {"status": "taken", "message": "This ID is already enrolled."}

        logger.info(f"Starting Multi-Stage Enrollment: {name} ({target_did})")
        
        ui_test_mode = os.environ.get('UI_TEST_MODE', '').lower() in ('1', 'true', 'yes') or                       os.environ.get('UI_MODE_TEST', '').lower() in ('1', 'true', 'yes')
        if ui_test_mode and getattr(system.sensor, 'set_samples', None):
             import glob
                                                                         
             fp_samples = sorted(glob.glob("fingerprint_dataset/U001/*.png"))
             if len(fp_samples) >= 3:
                 logger.info(f"Injecting mock fingerprint samples for testing enrollment")
                                                                             
                 system.sensor.set_samples(user_addr="mock_enroll", paths=fp_samples[:3])

        result = system.enroll(
            user_id=user_id, 
            name=name, 
            target_did=target_did,
            email=email,
            college=college,
            department=department,
            position=position
        )

        if result and result.get("status") == "ok":
                                       
             target_addr = target_did.split(":")[-1]
             if indexer:
                 indexer.add_user(target_addr, name, user_id=user_id, status="Active")
             return result
        else:
             return {"status": "error", "message": "Enrollment Failed"}
    except Exception as e:
        logger.error(f"Enroll error: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def verify_by_did(did):
    """Fast-path verification using a DID (e.g., from a QR scan)."""
    global system, indexer
    if not system:
        return {"status": "error", "message": "System not initialized"}
    
    try:
        logger.info(f"Verifying via DID: {did}")
        
        if not did.startswith("did:ethr:"):
             return {"status": "error", "message": "Invalid DID format"}
        
        target_addr = did.split(":")[-1]
        
        user_name = "User"
        try:
            cur = indexer.conn.cursor()
                                            
            res = cur.execute("SELECT name FROM users WHERE LOWER(address)=LOWER(?)", (target_addr,)).fetchone()
            if res: 
                user_name = res[0]
            else:
                                                                                      
                logger.warning(f"Address {target_addr} not found in local indexer cache.")
        except Exception as e:
            logger.debug(f"Indexer lookup failed: {e}")

        cid = system.verify(target_addr)
        
        block_number = None
        try:
            block_number = system.agent.w3.eth.block_number
        except:
            pass
        
        timeliness = 'UNSCHEDULED'
        expected_time = None
        try:
            schedule = indexer.get_user_schedule(target_addr)
            if schedule and schedule.get('time_blocks'):
                from datetime import datetime
                now = datetime.now()
                day_name = now.strftime('%a').upper()[:3]
                time_str = now.strftime('%H:%M')
                
                for block in schedule['time_blocks']:
                    if block.get('day') == day_name:
                        expected_time = block.get('start')
                        grace = schedule.get('grace_minutes', 15)
                        
                        expected_mins = int(expected_time.split(':')[0]) * 60 + int(expected_time.split(':')[1])
                        actual_mins = int(time_str.split(':')[0]) * 60 + int(time_str.split(':')[1])
                        
                        if actual_mins <= expected_mins + grace:
                            timeliness = 'ON_TIME'
                        else:
                            timeliness = 'LATE'
                        break
        except:
            pass
        
        return {
            "status": "ok", 
            "message": "Verification Successful", 
            "name": user_name,
            "cid": cid,
            "block_number": block_number,
            "timeliness": timeliness,
            "expected_time": expected_time
        }

    except Exception as e:
        logger.error(f"Verify DID Error: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def verify(user_input):
    global system, indexer
    if not system: 
        return {"status": "error", "message": "System not initialized"}
    
    try:
        logger.info(f"Verifying User Input: {user_input}")
        
        target_addr = indexer.lookup_user(user_input)
        if not target_addr:
             return {"status": "error", "message": f"User '{user_input}' not found."}
             
        user_name = "User"
        try:
            cur = indexer.conn.cursor()
            res = cur.execute("SELECT name FROM users WHERE address=?", (target_addr,)).fetchone()
            if res: user_name = res[0]
        except: pass
             
        cid = system.verify(target_addr)
        
        block_number = None
        try:
            block_number = system.agent.w3.eth.block_number
        except:
            pass
        
        timeliness = 'UNSCHEDULED'
        expected_time = None
        schedule = indexer.get_user_schedule(target_addr)
        
        if schedule and schedule.get('time_blocks'):
            from datetime import datetime
            now = datetime.now()
            day_name = now.strftime('%a').upper()[:3]
            time_str = now.strftime('%H:%M')
            
            for block in schedule['time_blocks']:
                if block.get('day') == day_name:
                    expected_time = block.get('start')
                    grace = schedule.get('grace_minutes', 15)
                    
                    expected_mins = int(expected_time.split(':')[0]) * 60 + int(expected_time.split(':')[1])
                    actual_mins = int(time_str.split(':')[0]) * 60 + int(time_str.split(':')[1])
                    
                    if actual_mins <= expected_mins + grace:
                        timeliness = 'ON_TIME'
                    else:
                        timeliness = 'LATE'
                    break
        
        return {
            "status": "ok", 
            "message": "Verification Successful", 
            "name": user_name,
            "cid": cid,
            "block_number": block_number,
            "timeliness": timeliness,
            "expected_time": expected_time
        }

    except Exception as e:
        logger.error(f"Verify Error: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_logs():
                                
    try:
        import subprocess
                                                                                          
        return {"status": "ok", "logs": "System Running...\n[INFO] RPC Connected.\n[INFO] Agent Ready."}
    except:
        return {"status": "error", "message": "Could not read logs"}

@eel.expose
def get_my_profile():
    global system
    if not system: return {"status": "error", "message": "System not initialized"}
    
    try:
        agent = system.agent
        contract = system.registry_contract
        
        my_addr = agent.account.address
        
        data = agent.get_user_profile(contract, my_addr)
        if "error" in data:
             return {"status": "error", "message": data["error"]}
        
        return {"status": "ok", "data": data}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def get_my_attendance():
    global system, indexer
    if not system or not indexer: return {"status": "error", "message": "System not initialized"}

    try:
        agent = system.agent
        my_addr = agent.account.address
        
        logs = indexer.get_user_attendance(my_addr)
        return {"status": "ok", "logs": logs}
    except Exception as e:
        return {"status": "error", "message": str(e)}

def start_app():
    import webbrowser
    import webbrowser
    
    import os
    host = os.getenv("PRISM_HOST", "localhost")
    port = int(os.getenv("PRISM_PORT", "8090"))
    
    try:
                                                            
        mode = 'chrome'
        if host == '0.0.0.0':
            logger.info(" Running in Docker (Headless). Waiting for Host Firefox...")
            mode = None                                  
            
        logger.info(f" Kiosk Server Starting at http://{host}:{port}")
        
        eel.start('kiosk.html', 
                  size=(1024, 768), 
                  block=True, 
                  host=host, 
                  port=port, 
                  mode=mode,
                  cmdline_args=['--no-sandbox'] if mode else [])
    except EnvironmentError:
                                                        
        logger.warning("Chrome not found, falling back to system browser")
        webbrowser.open(f'http://localhost:{port}/kiosk.html')
        eel.start('kiosk.html', mode=None, host=host, port=port, block=True)

if __name__ == "__main__":
    start_app()
