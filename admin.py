import eel
import logging
import sys
import os
import time
import datetime
import json
import threading
import subprocess
import yaml
import gevent
from gevent import monkey

monkey.patch_all()

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("ADMIN")

try:
    import docker
    docker_client = docker.from_env()
except Exception as e:
    logger.error(f"Failed to initialize Docker client: {e}")
    docker_client = None

from backend import Backend
from indexer import PrismIndexer

import os
base_dir=os.path.dirname(os.path.abspath(__file__))
eel.init(os.path.join(base_dir, 'web-react/dist'))

system = None
indexer = None

@eel.expose
def init_system():
    global system, indexer, sync_thread
    try:
        logger.info(" Initializing Production Admin Station...")
        if not system:
            ui_test_mode = os.environ.get('UI_TEST_MODE', '').lower() in ('1', 'true', 'yes') or \
                           os.environ.get('UI_MODE_TEST', '').lower() in ('1', 'true', 'yes')
            
            from bridge import LedgerBridge
            prod_bridge = LedgerBridge(config_path="blockchain/master.yaml")
            
            if ui_test_mode:
                logger.warning(" Running ADMIN in UI_TEST_MODE. Injecting MockFingerSensor and enabling camera.")
                from sensor_mocks import MockFingerSensor
                system = Backend(
                    require_hardware=False, 
                    initialize_sensors=True,
                    finger_sensor=MockFingerSensor(), 
                    bridge=prod_bridge
                )
            else:
                system = Backend(require_hardware=False, initialize_sensors=False, bridge=prod_bridge)
            
            if system.agent and system.agent.w3:
                if system.agent.w3.is_connected():
                    logger.info(f" Connected to Ledger at {system.agent.current_rpc_node}")
                else:
                    logger.warning(" Blockchain connected but check_health failed. Attempting failover...")
                    system._init_rpc_provider()
            
            try:
                if system.agent:
                     from indexer import PrismIndexer
                     indexer = PrismIndexer(agent=system.agent)
                     logger.info(" Indexer services initialized.")
                else:
                     logger.warning("Agent not ready, indexer skipped")
            except Exception as e:
                logger.error(f"Indexer init failed: {e}")
        
        if indexer and (not sync_thread or not sync_thread.is_alive()):
            sync_thread = threading.Thread(target=background_sync_loop, daemon=True)
            sync_thread.start()
            logger.info(" Background sync thread started")
        
        caps = system.get_capabilities()
        if not caps['canRevoke']:
            logger.critical("[ACCESS DENIED] This key does not have Admin (Revoke) privileges.")
            return {"status": "error", "message": "Access Denied: Not an Admin Device."}

        status_payload = {
            "status": "ok", 
            "message": "Admin System Initialized",
            "node": system.agent.current_rpc_node if system.agent else "Unknown",
            "block": system.agent.w3.eth.block_number if system.agent and system.agent.w3 else 0
        }
        logger.info(f" System State: Node={status_payload['node']}, Block={status_payload['block']}")
        return status_payload
    except Exception as e:
        logger.error(f"Init failed: {e}", exc_info=True)
        return {"status": "error", "message": str(e)}

sync_thread = None

def background_sync_loop():
    logger.info("Background Sync Loop Active")
    while True:
        if indexer:
            try:
                indexer.run_sync()
            except Exception as e:
                logger.error(f"Auto-Sync Error: {e}")
        time.sleep(10)

@eel.expose
def sync_ledger():
    """Manual trigger for ledger sync"""
    try:
        if indexer:
            indexer.run_sync()
            return {"status": "ok", "message": "Ledger Synced"}
        return {"status": "error", "message": "Indexer not ready"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_deep_sync():
    """Manual trigger for on-chain status reconciliation"""
    try:
        if indexer:
            indexer.sync_statuses()
            return {"status": "ok", "message": "Deep Sync Complete"}
        return {"status": "error", "message": "Indexer not ready"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_reset_indexer():
    """Hard reset indexer - clears DB and restarts sync from block 0"""
    try:
        if indexer:
            indexer.reset_index()
            indexer.run_sync()
            return {"status": "ok", "message": "Indexer Reset & Syncing from 0"}
        return {"status": "error", "message": "Indexer not ready"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def get_system_capabilities():
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
def enroll(uid, name, did, email=None, college=None, department=None, position=None):
    """Wraps backend enrollment."""
    if not system: return {"status": "error", "message": "System not initialized"}
    
    caps = system.get_capabilities()
    if not caps.get('canEnroll', False):
         return {"status": "error", "message": "Device not authorized to Enroll."}

    try:
        success = system.enroll(uid, name, did, email=email, college=college, department=department, position=position)
        if success:
             return {"status": "ok", "message": "Enrollment Successful"}
        else:
             return {"status": "error", "message": "Enrollment Failed"}
    except Exception as e:
        logger.error(f"Enroll Error: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def verify(uid): 
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        info_cid = system.verify(uid)
        return {"status": "ok", "message": "Verification Successful", "cid": info_cid}
    except Exception as e:
         return {"status": "error", "message": str(e)}


@eel.expose
def admin_revoke_user(target_addr, reason=None, comment=None):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent 
        contract = system.registry_contract
        if target_addr.lower() == agent.account.address.lower():
            return {"status": "error", "message": "Access Denied: You cannot revoke your own admin session/device."}
        from web3 import Web3
        try:
            checksum_addr = Web3.to_checksum_address(target_addr)
            profile_data = contract.functions.profiles(checksum_addr).call()
            is_valid = profile_data[2]
            did = profile_data[0]
            if not is_valid:
                if not did or did == "":
                    return {"status": "error", "message": "User does not exist on-chain"}
                return {"status": "error", "message": "User is already revoked"}
        except Exception as e:
            logger.warning(f"Pre-revocation status check failed for {target_addr}: {e}")
        if reason or comment:
            _log_audit_event(
                node_id=None, 
                action=f"REVOKE_USER:{target_addr[:10]}", 
                status=f"REASON:{reason or 'N/A'} COMMENT:{comment or 'N/A'}"
            )
        receipt = agent.revoke_user(contract, agent.account, agent.account.key, target_addr)
        if receipt and receipt.status == 1:
             return {
                 "status": "ok", 
                 "message": f"Revoked {target_addr}",
                 "txHash": receipt.transactionHash.hex() if hasattr(receipt, 'transactionHash') else None
             }
        else:
             return {"status": "error", "message": "Transaction failed or reverted"}
    except Exception as e:
        error_msg = str(e)
        if "execution reverted" in error_msg:
            return {"status": "error", "message": "Revocation failed: User might already be revoked or does not exist"}
        return {"status": "error", "message": error_msg}

@eel.expose
def admin_start_reissuance(target_addr, user_signature):
    """Starts the live biometric reissuance flow. Requires pre-signed REISSUE_CONSENT voucher."""
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent 
        contract = system.registry_contract
        
        profile_res = agent.get_user_profile(contract, target_addr)
        if "error" in profile_res:
            return {"status": "error", "message": f"Profile error: {profile_res['error']}"}
        
        profile = profile_res.get('profile')
        if not profile:
            return {"status": "error", "message": "Could not fetch user profile details."}
            
        existing_did = profile_res.get('did', '')
        if not existing_did:
            return {"status": "error", "message": "User has no existing DID on-chain."}
            
        profile_details = profile_res.get('profile', {})
        user_id = profile_details.get('identity', {}).get('user_id', '')
        name = profile_details.get('identity', {}).get('name', 'Unknown')
        
        metadata = profile_details.get('metadata', {})
        identity = profile_details.get('identity', {})
        
        email = metadata.get('email') or identity.get('email') or ''
        college = metadata.get('college') or identity.get('college') or ''
        department = metadata.get('department') or identity.get('department') or ''
        position = metadata.get('position') or identity.get('position') or ''
        
        sig_bytes = bytes.fromhex(user_signature.replace('0x', '')) if isinstance(user_signature, str) else user_signature
        
        if getattr(system.sensor, 'set_samples', None):
            import glob
            fp_samples = sorted(glob.glob('fingerprint_dataset/U001/*.png'))
            if len(fp_samples) >= 3:
                system.sensor.set_samples(user_addr=user_id, paths=fp_samples[:3])

        result = system.reissue_identity(
            user_id=user_id,

            name=name,
            existing_did=existing_did,
            target_addr=target_addr,
            user_signature=sig_bytes,
            email=email,
            college=college,
            department=department,
            position=position
        )
        
        if result.get("status") == "ok":
            _log_audit_event(None, f"REISSUE_USER:{target_addr[:10]}", "OK")
        return result
        
    except Exception as e:
        logger.error(f"Reissuance Error: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_consent_revocation(target_addr, user_signature):
    """Immediately revoke a user's identity using their pre-signed REVOKE_CONSENT voucher. Bypasses grace period."""
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        contract = system.registry_contract
        sig_bytes = bytes.fromhex(user_signature.replace('0x', '')) if isinstance(user_signature, str) else user_signature
        receipt = agent.consent_revocation(contract, agent.account, agent.account.key, target_addr, sig_bytes)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"CONSENT_REVOCATION:{target_addr[:10]}", "OK")
            return {"status": "ok", "message": f"Identity revoked (with user consent) for {target_addr[:10]}..."}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_scan_voucher_qr():
    """Scan a PRISM_VOUCHER QR code using the device camera. Returns parsed voucher data."""
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        raw = system.scan_qr(timeout=30)
        if not raw:
            return {"status": "error", "message": "No QR code detected"}
        
        if raw.startswith("PRISM_VOUCHER:"):
            payload = json.loads(raw[len("PRISM_VOUCHER:"):])
            return {
                "status": "ok",
                "voucher": {
                    "address": payload.get("addr", ""),
                    "contract": payload.get("contract", ""),
                    "nonce": payload.get("nonce", 0),
                    "signature": payload.get("sig", "")
                }
            }
        else:
            return {"status": "ok", "voucher": {"signature": raw, "address": "", "contract": "", "nonce": 0}}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_toggle_pause():
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent 
        contract = system.registry_contract
        receipt = agent.toggle_pause(contract, agent.account, agent.account.key)
        if receipt and receipt.status == 1:
             return {"status": "ok", "message": "Circuit Breaker Toggled"}
        else:
             return {"status": "error", "message": "Transaction Failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_set_enroll_auth(target_addr, status):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        contract = system.registry_contract
        receipt = agent.set_enroll_auth(contract, agent.account, agent.account.key, target_addr, status)
        if receipt and receipt.status == 1:
             return {"status": "ok", "message": f"Set ENROLL={status} for {target_addr}"}
        else:
             return {"status": "error", "message": "Transaction Failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_set_record_auth(target_addr, status):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        contract = system.registry_contract
        receipt = agent.set_record_auth(contract, agent.account, agent.account.key, target_addr, status)
        if receipt and receipt.status == 1:
             return {"status": "ok", "message": f"Set RECORD={status} for {target_addr}"}
        else:
             return {"status": "error", "message": "Transaction Failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_set_revoke_auth(target_addr, status):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        contract = system.registry_contract
        receipt = agent.set_revoke_auth(contract, agent.account, agent.account.key, target_addr, status)
        if receipt and receipt.status == 1:
             return {"status": "ok", "message": f"Set REVOKE={status} for {target_addr}"}
        else:
             return {"status": "error", "message": "Transaction Failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


@eel.expose
def admin_suspend_user(target_addr, reason=1):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        receipt = agent.suspend_user(system.registry_contract, agent.account, agent.account.key, target_addr, reason)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"SUSPEND_USER:{target_addr[:10]}", f"REASON:{reason}")
            return {"status": "ok", "message": f"User {target_addr[:10]}... suspended"}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_reinstate_user(target_addr):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        receipt = agent.reinstate_user(system.registry_contract, agent.account, agent.account.key, target_addr)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"REINSTATE_USER:{target_addr[:10]}", "OK")
            return {"status": "ok", "message": f"User {target_addr[:10]}... reinstated"}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_ban_user(target_addr):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        receipt = agent.ban_user(system.registry_contract, agent.account, agent.account.key, target_addr)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"BAN_USER:{target_addr[:10]}", "PERMANENT")
            return {"status": "ok", "message": f"User {target_addr[:10]}... PERMANENTLY banned"}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_request_revocation(target_addr):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        receipt = agent.request_revocation(system.registry_contract, agent.account, agent.account.key, target_addr)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"REQUEST_REVOCATION:{target_addr[:10]}", "PENDING")
            return {"status": "ok", "message": f"Revocation requested for {target_addr[:10]}... Grace period started."}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_cancel_revocation(target_addr):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        receipt = agent.cancel_revocation(system.registry_contract, agent.account, agent.account.key, target_addr)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"CANCEL_REVOCATION:{target_addr[:10]}", "OK")
            return {"status": "ok", "message": f"Revocation cancelled for {target_addr[:10]}..."}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_finalize_revocation(target_addr):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        receipt = agent.finalize_revocation(system.registry_contract, agent.account, agent.account.key, target_addr)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"FINALIZE_REVOCATION:{target_addr[:10]}", "OK")
            return {"status": "ok", "message": f"Revocation finalized for {target_addr[:10]}..."}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


@eel.expose
def admin_ban_device(device_addr):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        receipt = agent.ban_device(system.registry_contract, agent.account, agent.account.key, device_addr)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"BAN_DEVICE:{device_addr[:10]}", "PERMANENT")
            return {"status": "ok", "message": f"Device {device_addr[:10]}... PERMANENTLY banned"}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_register_kiosk(device_addr, enode_hash):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        if isinstance(enode_hash, str):
            enode_hash = bytes.fromhex(enode_hash.replace("0x", ""))
        receipt = agent.register_kiosk_enode(system.registry_contract, agent.account, agent.account.key, device_addr, enode_hash)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"REGISTER_KIOSK:{device_addr[:10]}", "OK")
            return {"status": "ok", "message": f"Kiosk {device_addr[:10]}... registered"}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_revoke_kiosk(device_addr):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        receipt = agent.revoke_kiosk_enode(system.registry_contract, agent.account, agent.account.key, device_addr)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"REVOKE_KIOSK:{device_addr[:10]}", "OK")
            return {"status": "ok", "message": f"Kiosk {device_addr[:10]}... enode revoked and permissions stripped"}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_set_remote_record_auth(target_addr, status):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        receipt = agent.set_remote_record_auth(system.registry_contract, agent.account, agent.account.key, target_addr, status)
        if receipt and receipt.status == 1:
            return {"status": "ok", "message": f"Set REMOTE_RECORD={status} for {target_addr}"}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_set_reissue_auth(target_addr, status):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        receipt = agent.set_reissue_auth(system.registry_contract, agent.account, agent.account.key, target_addr, status)
        if receipt and receipt.status == 1:
            return {"status": "ok", "message": f"Set REISSUE={status} for {target_addr}"}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_bind_device(owner_did, device_address=None):
    """
    Eel exposure for device binding logic.
    Derives an owner_key for a personal device and optionally whitelists it.
    """
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        from core.device_key import DeviceKeyManager
        import base64
        from datetime import datetime
        
        key_path = "storage/keys/device_root.key"
        if not os.path.exists(key_path):
            return {"status": "error", "message": f"Device root key not found at {key_path}"}
        
        manager = DeviceKeyManager(key_path)
        
        owner_key = manager.derive_user_key(owner_did)
        owner_key_b64 = base64.urlsafe_b64encode(owner_key).decode('ascii')
        
        whitelisted = False
        if device_address:
            agent = system.agent
            receipt = agent.set_remote_record_auth(system.registry_contract, agent.account, agent.account.key, device_address, True)
            if receipt and receipt.status == 1:
                whitelisted = True
        
        config = {
            "owner_key": owner_key_b64,
            "owner_did": owner_did,
            "device_address": device_address,
            "bound_at": datetime.utcnow().isoformat() + "Z",
            "version": "1.0"
        }
        
        manager.clear_cached_key()
        del owner_key
        
        return {
            "status": "ok", 
            "message": "Device bound successfully" + (" and whitelisted" if whitelisted else ""),
            "config": config,
            "whitelisted": whitelisted
        }
    except Exception as e:
        logger.error(f"Device binding failed: {e}")
        return {"status": "error", "message": str(e)}


@eel.expose
def admin_add_node(enode, kiosk_address=None):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        bridge = system.bridge
        if not hasattr(bridge, 'permissions_contract'):
            return {"status": "error", "message": "Permissions contract not loaded"}
        
        receipt = agent.add_node(bridge.permissions_contract, agent.account, agent.account.key, enode)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"ADD_NODE:{enode[:30]}", "OK")
            
            if kiosk_address and kiosk_address.strip():
                enode_hash = agent.w3.keccak(text=enode)
                k_receipt = agent.register_kiosk_enode(system.registry_contract, agent.account, agent.account.key, kiosk_address, enode_hash)
                if k_receipt and k_receipt.status == 1:
                    _log_audit_event(None, f"AUTO_REGISTER_KIOSK:{kiosk_address[:10]}", "OK")
                    return {"status": "ok", "message": "Node added to consensus and registered as Kiosk"}
                else:
                    return {"status": "warning", "message": "Node added but Kiosk registration failed"}
            
            return {"status": "ok", "message": "Node added to consensus"}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_remove_node(enode):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        bridge = system.bridge
        if not hasattr(bridge, 'permissions_contract'):
            return {"status": "error", "message": "Permissions contract not loaded"}
            
        enode_hash = agent.w3.keccak(text=enode)
        kiosk_addr = system.registry_contract.functions.enodeToKiosk(enode_hash).call()
        if kiosk_addr and kiosk_addr != "0x0000000000000000000000000000000000000000":
            agent.revoke_kiosk_enode(system.registry_contract, agent.account, agent.account.key, kiosk_addr)
            _log_audit_event(None, f"AUTO_REVOKE_KIOSK:{kiosk_addr[:10]}", "OK")
            
        receipt = agent.remove_node(bridge.permissions_contract, agent.account, agent.account.key, enode)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"REMOVE_NODE:{enode[:30]}", "OK")
            return {"status": "ok", "message": "Node removed from consensus" + (" and Kiosk revoked" if kiosk_addr != "0x0000000000000000000000000000000000000000" else "")}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_ban_node(enode):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        bridge = system.bridge
        if not hasattr(bridge, 'permissions_contract'):
            return {"status": "error", "message": "Permissions contract not loaded"}
            
        enode_hash = agent.w3.keccak(text=enode)
        kiosk_addr = system.registry_contract.functions.enodeToKiosk(enode_hash).call()
        if kiosk_addr and kiosk_addr != "0x0000000000000000000000000000000000000000":
            agent.revoke_kiosk_enode(system.registry_contract, agent.account, agent.account.key, kiosk_addr)
            _log_audit_event(None, f"AUTO_REVOKE_KIOSK:{kiosk_addr[:10]}", "OK")

        receipt = agent.ban_node(bridge.permissions_contract, agent.account, agent.account.key, enode)
        if receipt and receipt.status == 1:
            _log_audit_event(None, f"BAN_NODE:{enode[:30]}", "PERMANENT")
            return {"status": "ok", "message": "Node PERMANENTLY banned from consensus" + (" and Kiosk revoked" if kiosk_addr != "0x0000000000000000000000000000000000000000" else "")}
        return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_logs():
    return indexer.get_logs() if indexer else []

@eel.expose
def admin_search_users(query):
    if not indexer:
        return {"status": "error", "message": "Indexer not initialized"}
    try:
        cur = indexer.conn.cursor()
        rows = cur.execute("""
            SELECT address, name, user_id, status FROM users 
            WHERE name LIKE ? OR user_id = ? OR address LIKE ?
            LIMIT 10
        """, (f"%{query}%", query, f"{query}%")).fetchall()
        results = []
        for r in rows:
            address = r[0]
            local_status = r[3] or "Active"
            on_chain_status = local_status
            try:
                from web3 import Web3
                c_addr = Web3.to_checksum_address(address)
                profile_data = system.registry_contract.functions.profiles(c_addr).call()
                is_active = profile_data[2]
                on_chain_status = "Active" if is_active else "Revoked"
                if on_chain_status != local_status:
                    indexer.update_user_status(address, on_chain_status)
            except Exception as e:
                logger.warning(f"On-chain status check failed during multi-search for {address}: {e}")
            results.append({
                "address": address,
                "name": r[1] or "Unknown",
                "user_id": r[2] or "-",
                "status": on_chain_status
            })
        return {"status": "ok", "data": results}
    except Exception as e:
        logger.error(f"User search failed: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_suspend_device(device_addr, reason=1):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        contract = system.registry_contract
        nonce = agent.w3.eth.get_transaction_count(agent.account.address)
        tx = contract.functions.suspendDevice(device_addr, reason).build_transaction({
            'from': agent.account.address,
            'nonce': nonce,
            'gas': 200000,
            'gasPrice': 0,
            'chainId': agent.chain_id
        })
        signed = agent.w3.eth.account.sign_transaction(tx, agent.account.key)
        tx_hash = agent.w3.eth.send_raw_transaction(signed.raw_transaction)
        receipt = agent.w3.eth.wait_for_transaction_receipt(tx_hash)
        if receipt.status == 1:
            _log_audit_event(None, f"SUSPEND_DEVICE:{device_addr[:10]}", f"REASON:{reason}")
            return {"status": "ok", "message": f"Device {device_addr[:10]}... suspended"}
        else:
            return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        logger.error(f"Suspend device failed: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_reinstate_device(device_addr):
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        agent = system.agent
        contract = system.registry_contract
        nonce = agent.w3.eth.get_transaction_count(agent.account.address)
        tx = contract.functions.reinstateDevice(device_addr).build_transaction({
            'from': agent.account.address,
            'nonce': nonce,
            'gas': 200000,
            'gasPrice': 0,
            'chainId': agent.chain_id
        })
        signed = agent.w3.eth.account.sign_transaction(tx, agent.account.key)
        tx_hash = agent.w3.eth.send_raw_transaction(signed.raw_transaction)
        receipt = agent.w3.eth.wait_for_transaction_receipt(tx_hash)
        if receipt.status == 1:
            _log_audit_event(None, f"REINSTATE_DEVICE:{device_addr[:10]}", "OK")
            return {"status": "ok", "message": f"Device {device_addr[:10]}... reinstated"}
        else:
            return {"status": "error", "message": "Transaction failed"}
    except Exception as e:
        logger.error(f"Reinstate device failed: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_authorized_nodes():
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        bridge = system.bridge
        if not hasattr(bridge, 'permissions_contract'):
             return {"status": "error", "message": "Permissions contract not loaded"}
        nodes = system.agent.get_authorized_nodes(bridge.permissions_contract)
        return {"status": "ok", "data": nodes}
    except Exception as e:
        logger.error(f"Get authorized nodes failed: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_paused_status():
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        contract = system.registry_contract
        is_paused = contract.functions.systemPaused().call()
        return {
            "status": "ok", 
            "paused": is_paused,
            "message": "System PAUSED" if is_paused else "System ACTIVE"
        }
    except Exception as e:
        logger.error(f"Get paused status failed: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_contract_owner():
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        contract = system.registry_contract
        owner = contract.functions.owner().call()
        is_current_user = (owner.lower() == system.agent.account.address.lower())
        return {
            "status": "ok",
            "owner": owner,
            "isCurrentUser": is_current_user
        }
    except Exception as e:
        logger.error(f"Get contract owner failed: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_contract_info():
    if not system: return {"status": "error", "message": "System not initialized"}
    bridge = system.bridge
    return {
        "status": "ok",
        "registry": bridge.registry_address,
        "attendance": bridge.attendance_address,
        "permissions": getattr(bridge, 'permissions_address', '0x...')
    }

@eel.expose
def admin_get_audit_trail(limit=20):
    try:
        audit_file = "storage/logs/node_audit.jsonl"
        events = []
        if os.path.exists(audit_file):
            with open(audit_file, "r") as f:
                lines = f.readlines()[-limit:]
                for line in lines:
                    try:
                        events.append(json.loads(line))
                    except: continue
        events.reverse()
        return {"status": "ok", "data": events}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_all_attendance():
    if not indexer: return {"status": "error", "message": "Indexer not initialized"}
    try:
        cur = indexer.conn.cursor()
        rows = cur.execute("""
            SELECT u.name, u.address, a.timestamp, a.device_id, a.status, u.user_id
            FROM attendance_log a
            LEFT JOIN users u ON a.user_address = u.address
            ORDER BY a.timestamp DESC
            LIMIT 100
        """).fetchall()
        data = []
        for r in rows:
            ts = r[2] if r[2] else 0
            d = {
                "name": r[0] or "Unknown",
                "did": f"did:ethr:{r[1]}" if r[1] else "Unknown",
                "date": time.strftime("%Y-%m-%d", time.localtime(ts)),
                "time": time.strftime("%H:%M:%S", time.localtime(ts)),
                "location": (r[3][:10] + "...") if r[3] and len(r[3]) > 10 else (r[3] or "Unknown"),
                "status": "Active" if r[4] == "SUCCESS" else "Failed",
                "dept": "N/A"
            }
            data.append(d)
        return {"status": "ok", "data": data}
    except Exception as e:
        logger.error(f"Failed to fetch attendance: {e}")
        return {"status": "error", "message": str(e)}


@eel.expose
def admin_set_schedule(user_address, schedule_data):
    if not indexer: return {"status": "error", "message": "Indexer not initialized"}
    if not system: return {"status": "error", "message": "System not initialized"}
    admin_addr = system.get_device_address()
    try:
        from web3 import Web3
        c_addr = Web3.to_checksum_address(user_address)
        profile_data = system.registry_contract.functions.profiles(c_addr).call()
        is_active = profile_data[2]
        if not is_active:
            indexer.update_user_status(user_address, "Revoked")
            return {"status": "error", "message": "Cannot assign schedule to a revoked user"}
        else:
            indexer.update_user_status(user_address, "Active")
    except Exception as e:
        logger.warning(f"On-chain status check failed for {user_address}: {e}")
    success = indexer.set_user_schedule(user_address, schedule_data, admin_addr)
    if success: return {"status": "ok", "message": "Schedule assigned"}
    return {"status": "error", "message": "Failed to assign schedule"}

@eel.expose
def admin_get_schedule(user_address):
    if not indexer: return {"status": "error", "message": "Indexer not initialized"}
    schedule = indexer.get_user_schedule(user_address)
    return {"status": "ok", "data": schedule}

@eel.expose
def admin_search_user(user_id):
    if not indexer: return {"status": "error", "message": "Indexer not initialized"}
    try:
        cur = indexer.conn.cursor()
        res = cur.execute("""
            SELECT address, name, user_id, status FROM users WHERE user_id = ?
        """, (user_id,)).fetchone()
        if res:
            address = res[0]
            name = res[1]
            user_id = res[2]
            local_status = res[3]
            on_chain_status = "Revoked"
            try:
                from web3 import Web3
                c_addr = Web3.to_checksum_address(address)
                profile_data = system.registry_contract.functions.profiles(c_addr).call()
                is_active = profile_data[2]
                on_chain_status = "Active" if is_active else "Revoked"
                if on_chain_status != local_status:
                    indexer.update_user_status(address, on_chain_status)
            except Exception as e:
                logger.warning(f"On-chain status check failed for {address}: {e}")
                on_chain_status = local_status
            return {"status": "ok", "data": {
                "address": address,
                "name": name,
                "user_id": user_id,
                "status": on_chain_status,
                "local_status": local_status
            }}
        return {"status": "error", "message": "User not found"}
    except Exception as e:
        logger.error(f"Search user failed: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_all_schedules():
    if not indexer: return {"status": "error", "message": "Indexer not initialized"}
    schedules = indexer.get_all_schedules()
    return {"status": "ok", "data": schedules}

@eel.expose
def admin_get_user_profile(identifier):
    if not indexer: return {"status": "error", "message": "Indexer not initialized"}
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        cur = indexer.conn.cursor()
        if identifier.startswith("0x"): user_address = identifier
        else:
            res = cur.execute("SELECT address FROM users WHERE user_id = ?", (identifier,)).fetchone()
            if not res: return {"status": "error", "message": "User not found"}
            user_address = res[0]
        user_row = cur.execute("""
            SELECT address, name, user_id, status, profile_cid, position, department, email
            FROM users WHERE address = ?
        """, (user_address,)).fetchone()
        if not user_row: return {"status": "error", "message": "User not found in index"}
        profile = {
            "address": user_row[0],
            "name": user_row[1] or "Unknown",
            "user_id": user_row[2] or "-",
            "localStatus": user_row[3] or "Unknown",
            "position": user_row[5],
            "department": user_row[6],
            "email": user_row[7]
        }
        try:
            from web3 import Web3
            contract = system.registry_contract
            c_addr = Web3.to_checksum_address(user_address)
            on_chain = contract.functions.profiles(c_addr).call()
            profile["onChainValid"] = on_chain[2]
            profile["chainVerified"] = True
        except Exception as e:
            profile["onChainValid"] = None
            profile["chainVerified"] = False
        schedule = indexer.get_user_schedule(user_address)
        profile["schedule"] = {
            "type": schedule.get("schedule_type") if schedule else None,
            "graceMinutes": schedule.get("grace_minutes") if schedule else None,
            "blockCount": len(schedule.get("time_blocks", [])) if schedule else 0,
            "timeBlocks": schedule.get("time_blocks", []) if schedule else []
        }
        stats = indexer.get_user_stats(user_address)
        profile["stats"] = stats
        recent = indexer.get_user_attendance(user_address, limit=5)
        profile["recentActivity"] = [
            {
                "timestamp": a["timestamp"],
                "date": time.strftime("%Y-%m-%d", time.localtime(a["timestamp"])),
                "time": time.strftime("%H:%M:%S", time.localtime(a["timestamp"])),
                "status": a["status"],
                "device": a["device_id"][:10] + "..." if a["device_id"] and len(a["device_id"]) > 10 else a["device_id"]
            }
            for a in recent
        ]
        return {"status": "ok", "data": profile}
    except Exception as e:
        logger.error(f"Get user profile failed: {e}")
        return {"status": "error", "message": str(e)}



@eel.expose
def admin_get_attendance_with_status():
    if not indexer: return {"status": "error", "message": "Indexer not initialized"}
    try:
        data = indexer.get_attendance_with_status(limit=100)
        result = []
        active_addresses = {a['user_address'] for a in data if a['user_status'] == 'Active'}
        from web3 import Web3
        for addr in active_addresses:
            try:
                checksum_addr = Web3.to_checksum_address(addr)
                profile_data = system.registry_contract.functions.profiles(checksum_addr).call()
                is_active = profile_data[2]
                if not is_active:
                    indexer.update_user_status(addr, "Revoked")
                    for a in data:
                        if a['user_address'] == addr: a['user_status'] = "Revoked"
            except: pass
        for a in data:
            ts = a['timestamp']
            result.append({
                "name": a['name'] or "Unknown",
                "user_id": a['user_id'],
                "did": f"did:ethr:{a['user_address']}",
                "date": time.strftime("%Y-%m-%d", time.localtime(ts)),
                "time": time.strftime("%H:%M:%S", time.localtime(ts)),
                "expected_time": a['expected_time'] or "-",
                "timeliness": a['timeliness'],
                "location": a['device_id'] or "-",
                "status": a['status'],
                "user_status": a['user_status'],
                "department": a.get('department', '-'),
                "position": a.get('position', '-')
            })
        return {"status": "ok", "data": result}
    except Exception as e:
        logger.error(f"Failed to fetch attendance with status: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_calendar_attendance(user_address=None, start_date=None, end_date=None):
    if not indexer: return {"status": "error", "message": "Indexer not initialized"}
    try:
        import datetime
        cur = indexer.conn.cursor()
        query = """
            SELECT a.id, a.user_address, a.timestamp, a.device_id, a.status, u.name, u.user_id
            FROM attendance_log a
            JOIN users u ON a.user_address = u.address
            WHERE 1=1
        """
        params = []
        if user_address:
            query += " AND a.user_address = ?"
            params.append(user_address)
        if start_date:
            start_ts = datetime.datetime.strptime(start_date, "%Y-%m-%d").timestamp()
            query += " AND a.timestamp >= ?"
            params.append(start_ts)
        if end_date:
            end_ts = datetime.datetime.strptime(end_date, "%Y-%m-%d").timestamp() + 86400
            query += " AND a.timestamp < ?"
            params.append(end_ts)
        query += " ORDER BY a.timestamp DESC LIMIT 500"
        rows = cur.execute(query, params).fetchall()
        calendar_data = {}
        for row in rows:
            ts = row[2]
            date_str = time.strftime("%Y-%m-%d", time.localtime(ts))
            if date_str not in calendar_data: calendar_data[date_str] = []
            calendar_data[date_str].append({
                "id": row[0],
                "user_address": row[1],
                "time": time.strftime("%H:%M:%S", time.localtime(ts)),
                "device_id": row[3],
                "status": row[4],
                "name": row[5],
                "user_id": row[6]
            })
        return {"status": "ok", "data": calendar_data}
    except Exception as e:
        logger.error(f"Calendar attendance query failed: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_delete_schedule(user_address):
    if not indexer: return {"status": "error", "message": "Indexer not initialized"}
    try:
        cur = indexer.conn.cursor()
        cur.execute("DELETE FROM user_schedules WHERE user_address = ?", (user_address,))
        indexer.conn.commit()
        return {"status": "ok", "message": "Schedule removed"}
    except Exception as e:
        logger.error(f"Delete schedule failed: {e}")
        return {"status": "error", "message": str(e)}


def _load_cluster_nodes():
    """Reads provision/network_config.yaml and returns {node_id(int): host_str}."""
    config_path = os.path.join(os.path.dirname(__file__), "provision", "network_config.yaml")
    try:
        with open(config_path) as f:
            cfg = yaml.safe_load(f)
        nodes = {}
        for k, v in cfg.get("nodes", {}).items():
            nid = int(k)
            if isinstance(v, dict):
                nodes[nid] = v.get("host", f"prism@{v['ip']}")
            else:
                nodes[nid] = v
        return nodes
    except Exception as e:
        logger.error(f"Failed to load network_config.yaml: {e}")
        return {}

def _ssh_cmd(host, cmd, timeout=10):
    """Run a command on a remote node via SSH. Returns (success, stdout)."""
    try:
        result = subprocess.run(
            ["ssh", "-o", "StrictHostKeyChecking=no", "-o", f"ConnectTimeout={timeout}", host, cmd],
            capture_output=True, text=True, timeout=timeout + 5
        )
        return result.returncode == 0, result.stdout.strip()
    except Exception as e:
        return False, str(e)

AUDIT_LOG_FILE = "node_audit.jsonl"

def _log_audit_event(node_id, action, status):
    entry = {
        "timestamp": time.time(),
        "human_time": time.strftime("%Y-%m-%d %H:%M:%S"),
        "node_id": node_id,
        "action": action,
        "status": status
    }
    try:
        with open(AUDIT_LOG_FILE, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except: pass

@eel.expose
def admin_toggle_node(node_id, action):
    """Start or stop a remote quorum-node container via SSH."""
    if action not in ["start", "stop"]:
        return {"status": "error", "message": f"Invalid action: {action}"}

    nodes = _load_cluster_nodes()
    node_id = int(node_id)
    host = nodes.get(node_id)
    if not host:
        return {"status": "error", "message": f"Node {node_id} not found in network_config.yaml."}

    if action == "stop":
        active_node_id = _get_active_node_id()
        if active_node_id and active_node_id == node_id:
            return {"status": "error", "message": f"Cannot teardown Node {node_id} — this is your active RPC connection."}

    _log_audit_event(node_id, action, "INITIATED")

    ok, output = _ssh_cmd(host, f"docker {action} quorum-node")
    if ok:
        _log_audit_event(node_id, action, "SUCCESS")
        return {"status": "ok", "message": f"Node {node_id} {action}ed"}
    else:
        _log_audit_event(node_id, action, f"ERROR: {output}")
        return {"status": "error", "message": f"SSH to {host} failed: {output}"}

def _get_active_node_id():
    """Determine which node the admin is currently connected to via RPC."""
    try:
        if system and system.agent and system.agent.w3:
            rpc_url = system.agent.config.get('network', {}).get('rpc_url', '')
            nodes = _load_cluster_nodes()
            for nid, host in nodes.items():
                ip = host.split("@")[-1] if "@" in host else host
                if ip in rpc_url:
                    return nid
    except Exception:
        pass
    return None

@eel.expose
def admin_get_cluster_status():
    """Query each remote node's quorum-node container status via SSH."""
    nodes = _load_cluster_nodes()
    cluster_status = []
    active_count = 0

    last_intents = {}
    if os.path.exists(AUDIT_LOG_FILE):
        try:
            with open(AUDIT_LOG_FILE, "r") as f:
                for line in f:
                    try:
                        record = json.loads(line)
                        if record['status'] == 'SUCCESS':
                            last_intents[record['node_id']] = record['action']
                    except: pass
        except: pass

    for node_id, host in nodes.items():
        ip = host.split("@")[-1] if "@" in host else host
        node_data = {"id": node_id, "container": "quorum-node", "ip": ip, "status": "unknown", "reason": "unknown", "running": False}

        ok, output = _ssh_cmd(host, "docker inspect -f '{{.State.Status}}' quorum-node", timeout=5)
        if ok and output:
            node_data['status'] = output
            node_data['running'] = (output == 'running')
            if output == 'running':
                active_count += 1
                node_data['reason'] = 'NORMAL'
            else:
                last_action = last_intents.get(node_id, 'start')
                node_data['reason'] = 'MANUAL_STOP' if last_action == 'stop' else 'CRASHED'
        else:
            node_data['status'] = 'unreachable'
            node_data['reason'] = 'SSH_FAILED'

        cluster_status.append(node_data)

    return {"status": "ok", "nodes": cluster_status, "activeCount": active_count, "downCount": len(nodes) - active_count}

def _get_cluster_metrics():
    try:
        cmd = ["docker", "stats", "--no-stream", "--format", "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}"]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
        
        consensus = []
        ipfs_nodes = []
        ai_services = []
        
        for line in res.stdout.strip().split('\n'):
            if not line: continue
            try:
                name, cpu, mem = line.split('|')
                cpu_val = float(cpu.strip().replace('%', ''))
                mem_str = mem.split('/')[0].strip()
                mem_val = 0.0
                if 'GiB' in mem_str: mem_val = float(mem_str.replace('GiB', '')) * 1024
                elif 'MiB' in mem_str: mem_val = float(mem_str.replace('MiB', ''))
                elif 'KiB' in mem_str: mem_val = float(mem_str.replace('KiB', '')) / 1024
                
                entry = {'name': name, 'cpu': cpu_val, 'mem': mem_val}
                
                entry = {'name': name, 'cpu': cpu_val, 'mem': mem_val}
                
                if 'quorum' in name: consensus.append(entry)
                elif 'ipfs' in name: ipfs_nodes.append(entry)
                elif 'validator-ai' in name or 'biometric' in name: ai_services.append(entry)
            except: continue
        
        return {
            "consensus": consensus,
            "ipfs": ipfs_nodes,
            "ai": ai_services
        }
    except Exception as e:
        logger.error(f"Metrics Error: {e}")
        return None

@eel.expose
def admin_get_dashboard_detailed():
    if not system: return {"status": "error", "message": "System not initialized"}
    stats = {}
    try:
        if not system.agent.w3 or not system.agent.w3.is_connected(): system.agent._connect_to_chain()
        if system.agent.w3 and system.agent.w3.is_connected():
            peer_count = system.agent.w3.net.peer_count
            stats['activeNodes'] = peer_count + 1
            stats['nodesDown'] = max(0, 4 - stats['activeNodes'])
            stats['blockHeight'] = system.agent.w3.eth.block_number
            stats['connectedNode'] = getattr(system.agent, 'current_rpc_node', 'Unknown')
        else:
            stats['activeNodes'] = 0
            stats['nodesDown'] = 4
            stats['blockHeight'] = 0
            stats['connectedNode'] = "Disconnected"
        if system.agent.ipfs:
            try:
                repo = system.agent.ipfs.repo.stat()
                stats['ipfsSize'] = f"{repo['RepoSize'] / (1024*1024):.2f} MB"
                stats['ipfsObjects'] = repo['NumObjects']
            except: stats['ipfsSize'] = "Unavailable"
        else: stats['ipfsSize'] = "Not Connected"
        
        breakdown = indexer.get_stats_breakdown()
        stats['totalCheckins'] = breakdown['total_checkins']
        stats['successRate'] = breakdown['success_rate']
        stats['personalCheckins'] = breakdown['personal_count']
        stats['personalFailures'] = breakdown.get('personal_failures', 0)
        stats['kioskBreakdown'] = breakdown['kiosk_breakdown']
        stats['kioskFailures'] = breakdown.get('kiosk_failures', 0)
        stats['todayVolume'] = breakdown['total_checkins'] 
        stats['adminDid'] = system.agent.did
        stats['adminAddress'] = system.agent.account.address
        
        metrics = _get_cluster_metrics()
        if metrics:
            stats['cluster'] = metrics
            
        return {"status": "ok", "data": stats}
    except Exception as e:
        logger.error(f"Stats Error: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_devices():
    if not system: return {"status": "error", "message": "System not initialized"}
    try:
        cur = indexer.conn.cursor()
        rows = cur.execute("""
            SELECT device_id, MAX(timestamp) as last_seen FROM attendance_log 
            WHERE device_id IS NOT NULL AND device_id != 'Unknown' GROUP BY device_id
        """).fetchall()
        devices = [{
            "name": "Admin Station", "id": "ADM-01", "type": "admin",
            "address": system.agent.account.address, "perms": {"enroll": True, "record": True, "revoke": True},
            "status": "Online", "is_self": True
        }]
        now = time.time()
        for r in rows:
            dev_addr = r[0]
            if dev_addr == system.agent.account.address: continue
            perms = system.agent.check_permissions(system.registry_contract, dev_addr)
            is_personal = cur.execute("SELECT 1 FROM attendance_log WHERE device_id=? AND user_address=? LIMIT 1", (dev_addr, dev_addr)).fetchone()
            devices.append({
                "name": f"Device {dev_addr[:6]}", "id": dev_addr, "type": "personal" if is_personal else "kiosk",
                "address": dev_addr, "perms": perms, "status": "Offline" if (now - r[1]) > 3600 else "Active"
            })
        return {"status": "ok", "data": devices}
    except Exception as e: return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_node_logs(node_id, lines=50):
    container_names = {1: "sim-quorum-1", 2: "sim-quorum-2", 3: "sim-quorum-3", 4: "sim-quorum-4"}
    container = container_names.get(node_id)
    if not container: return {"status": "error", "message": "Invalid node ID"}
    try:
        result = subprocess.run(["docker", "logs", "--tail", str(lines), container], capture_output=True, text=True, timeout=5)
        return {"status": "ok", "logs": result.stdout + result.stderr, "nodeId": node_id}
    except Exception as e: return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_users():
    """Restored API for UserManagementView - triggers sync on call"""
    if not indexer: return {"status": "error", "message": "Indexer not initialized"}
    try:
        indexer.run_sync()
        
        cur = indexer.conn.cursor()
        rows = cur.execute("SELECT address, name, user_id, status, department, position, email, college FROM users ORDER BY name ASC").fetchall()
        data_map = {}
        for r in rows:
            if not r[0]: continue
            key = r[0].lower()
            if key not in data_map:
                data_map[key] = {
                    "address": r[0], 
                    "name": r[1] or "Unknown", 
                    "user_id": r[2] or "-", 
                    "status": r[3] or "Unknown",
                    "department": r[4] or "-",
                    "position": r[5] or "-",
                    "email": r[6] or "-",
                    "college": r[7] or "-"
                }
        return {"status": "ok", "data": list(data_map.values())}
    except Exception as e: return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_user_details(address):
    """Detailed profile view with aggregated stats"""
    if not indexer: return {"status": "error", "message": "Indexer not initialized"}
    try:
        address = address.lower()
        cur = indexer.conn.cursor()
        
        user = cur.execute("SELECT address, name, user_id, status, department, position, email, enrollment_device, college FROM users WHERE LOWER(address)=?", (address,)).fetchone()
        if not user: return {"status": "error", "message": "User not found"}
        
        profile = {
            "address": user[0], "name": user[1], "user_id": user[2], "status": user[3],
            "department": user[4] or "-", "position": user[5] or "-", "email": user[6] or "-",
            "enrollment_device": user[7] or "Unknown", "college": user[8] or "-"
        }
        
        total = cur.execute("SELECT COUNT(*) FROM attendance_log WHERE LOWER(user_address)=?", (address,)).fetchone()[0]
        successful = cur.execute("SELECT COUNT(*) FROM attendance_log WHERE LOWER(user_address)=? AND status='SUCCESS'", (address,)).fetchone()[0]
        failed = cur.execute("SELECT COUNT(*) FROM attendance_log WHERE LOWER(user_address)=? AND status!='SUCCESS'", (address,)).fetchone()[0]
        
        logs = indexer.get_attendance_with_status(address, limit=1000)
        on_time = sum(1 for l in logs if l.get('timeliness') == "ON_TIME")
        late = sum(1 for l in logs if l.get('timeliness') == "LATE")
        
        device_rows = cur.execute("""
            SELECT device_id, COUNT(*) as count, MAX(timestamp) as last_used 
            FROM attendance_log 
            WHERE LOWER(user_address)=? 
            GROUP BY device_id
        """, (address,)).fetchall()
        
        devices = []
        for r in device_rows:
            dev_id = r[0]
            is_personal = (dev_id.lower() == address)
            devices.append({
                "device_id": dev_id,
                "count": r[1],
                "last_used": r[2],
                "type": "Personal" if is_personal else "Kiosk" # Simple heuristic
            })
            
        schedule_row = cur.execute("SELECT schedule_type, time_blocks, grace_minutes, effective_from FROM user_schedules WHERE LOWER(user_address)=?", (address,)).fetchone()
        schedule = None
        if schedule_row:
             schedule = {
                 "type": schedule_row[0],
                 "blocks": json.loads(schedule_row[1]) if schedule_row[1] else [],
                 "grace": schedule_row[2],
                 "effective": schedule_row[3]
             }

        return {
            "status": "ok",
            "profile": profile,
            "stats": {
                "total": total,
                "successful": successful,
                "failed": failed,
                "on_time": on_time,
                "late": late,
                "success_rate": round(successful/total*100, 1) if total > 0 else 0
            },
            "devices": devices,
            "schedule": schedule,
            "history": logs[:100] # Return recent 100 logs
        }
    except Exception as e: return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_departments():
    """Fetch unique departments for filtering"""
    if not indexer: return {"status": "ok", "data": []}
    try:
        cur = indexer.conn.cursor()
        rows = cur.execute("SELECT DISTINCT department FROM users WHERE department IS NOT NULL AND department != '-'").fetchall()
        depts = sorted([r[0] for r in rows if r[0]])
        return {"status": "ok", "data": depts}
    except Exception as e:
        logger.error(f"Error fetching departments: {e}")
        return {"status": "error", "message": str(e)}

@eel.expose
def admin_get_24h_volume():
    """Get transaction volume for the last 24 hours (hourly buckets)"""
    if not indexer: return []
    try:
        cur = indexer.conn.cursor()
        now = int(time.time())
        day_ago = now - 86400
        
        rows = cur.execute("""
            SELECT strftime('%H:00', datetime(CAST(timestamp AS INTEGER), 'unixepoch', 'localtime')) as hour, COUNT(*) 
            FROM attendance_log 
            WHERE timestamp >= ? 
            GROUP BY hour
            ORDER BY min(timestamp) ASC
        """, (day_ago,)).fetchall()
        
        data_map = {r[0]: r[1] for r in rows}
        
        current_hour = datetime.datetime.fromtimestamp(now).hour
        final_list = []
        for i in range(24):
            h = (current_hour - 23 + i) % 24
            h_str = f"{h:02d}:00"
            count = data_map.get(h_str, 0)
            final_list.append({"time": h_str, "count": count})
            
        return final_list
    except Exception as e: 
        print(f"Volume error: {e}")
        return []

def start_app():
    import webbrowser
    try: eel.start('index.html', size=(1280, 800), block=True, port=8092)
    except:
        webbrowser.open('http://localhost:8092/index.html')
        eel.start('index.html', mode=None, host='0.0.0.0', port=8092, block=True)

if __name__ == "__main__":
    start_app()
