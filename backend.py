import time
import secrets
import logging
import os
import cv2
import base64
import numpy as np
import json
import hashlib
import hmac

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

from instrumentation import logger_instance as instr

from core.exceptions import HardwareError
from core.settings import sys_config
                      
from sensor import FingerprintSensor
from prism.vault import AESVault
from bridge import LedgerBridge

class SecurityError(Exception):
    """Raised when authentication fails (spoofing, wrong user, etc)."""
    pass

class Backend:

    def __init__(self, finger_sensor=None, bridge=None, require_hardware=True, initialize_sensors=True):
        """
        Initialize the Backend.
        """
                    
        self.face_config = sys_config.load("face")
        self.finger_config = sys_config.load("finger")
        
        from face import FacePreprocessor, FaceEmbedder, KeyManager
        from networks import CFPADRuntime
        
        self.face_preproc = FacePreprocessor(self.face_config)
        self.pad_runtime = CFPADRuntime(self.face_config.pad)
        self.face_embedder = FaceEmbedder(self.face_config.embedder)
        self.key_manager = KeyManager(self.face_config)
        
        from prism_sdk.fingerprint import FingerprintExtractor
        system_cfg = getattr(self.finger_config, "system", None)
        finger_device = getattr(system_cfg, "device", "cpu") if system_cfg else "cpu"
        self.finger_pipeline = FingerprintExtractor(device=finger_device)
        self.vault = AESVault()
        
        self.hardware_available = False
        
        from sensor import FingerprintSensor, CameraSensor
        
        if initialize_sensors:
            if finger_sensor:
                self.sensor = finger_sensor
                self.hardware_available = True
            else:
                self.sensor = FingerprintSensor()
                if self.sensor.connect():
                    self.hardware_available = True
                else:
                    if require_hardware:
                        logger.error(" Fingerprint Sensor Required. No hardware detected.")
                        raise RuntimeError("Fingerprint hardware required but not available")
                    else:
                        logger.warning(" Fingerprint hardware not available. Running in RESTRICTED mode.")
            
            face_sys_cfg = getattr(self.face_config, "system", None)
            cam_idx = getattr(face_sys_cfg, "camera_index", 0) if face_sys_cfg else 0
            self._cam = CameraSensor(index=cam_idx)
            if self._cam.connect():
                logger.info(" Camera initialized and flushing (Warm Idle).")
            else:
                logger.warning(" Camera hardware not available.")
        else:
            logger.info(" Sensor initialization skipped (Admin/Headless Mode)")
            self.sensor = None
            self._cam = None
            self.hardware_available = False

        self.busy = False

        if bridge:
             self.bridge = bridge
        else:
             self.bridge = LedgerBridge()
        
        network_config = sys_config.load("network")
        net_cfg = getattr(network_config, "network", None)
        if net_cfg:
            self.rpc_nodes = getattr(net_cfg, "rpc_nodes", [])
            if not self.rpc_nodes:
                single_rpc = getattr(net_cfg, "rpc_url", None)
                self.rpc_nodes = [single_rpc] if single_rpc else ["http://127.0.0.1:8545"]
        else:
                                                      
            self.rpc_nodes = ["http://127.0.0.1:8545"]
        
        env_rpc = os.getenv("PRISM_RPC")
        if env_rpc:
            logger.info(f" Overriding RPC from environment: {env_rpc}")
            self.rpc_nodes = [env_rpc]
            
        if isinstance(self.rpc_nodes, str): self.rpc_nodes = [self.rpc_nodes]
        
        self._init_rpc_provider()
        self.agent = self.bridge.agent 
        self.registry_contract = self.bridge.registry_contract 
        self._cancel_flag = False

    @staticmethod
    def _expose_cancellation():
        """Expose cancel function to Eel."""
        import eel
        @eel.expose
        def cancel_operation():
            global backend_instance
            if backend_instance:
                backend_instance.cancel()

    def cancel(self):
        """Signals any running blocking operation to abort."""
        logger.info(" Cancellation signal received.")
        self._cancel_flag = True
        self.busy = False                             

    def stop(self):
        """Full cleanup of all resources/sensors."""
        logger.info(" Stopping Backend and releasing sensors...")
        if hasattr(self, '_cam') and self._cam:
            self._cam.release()
        if hasattr(self, 'sensor') and self.sensor:
            if hasattr(self.sensor, 'disconnect'):
                self.sensor.disconnect()
        self.busy = False

    def _init_rpc_provider(self):
        """Picks a healthy RPC node from the list."""
        import random
        from web3 import Web3
        nodes = self.rpc_nodes.copy()
        random.shuffle(nodes)
        
        selected_node = None
        for url in nodes:
            try:
                w3 = Web3(Web3.HTTPProvider(url))
                if w3.is_connected():
                    selected_node = url
                    logger.info(f" Load Balancer: Connected to Node {url}")
                    if self.bridge.agent:
                        self.bridge.agent.w3 = w3
                        self.bridge.reload_contracts() 
                    break
            except Exception as e:
                logger.warning(f"Node {url} unreachable: {e}")
        
        if not selected_node:
            logger.critical(" ALL RPC NODES UNREACHABLE.")
        
    def get_capabilities(self):
        if not self.agent or not self.registry_contract:
            return {"canEnroll": False, "canRecord": False, "canRevoke": False}
        return self.agent.check_permissions(self.registry_contract, self.agent.account.address)

    def get_device_address(self):
        if self.agent and self.agent.account:
            return self.agent.account.address
        return "Unknown"

    def _derive_user_key(self, did):
        master_seed = b"PRISM_MASTER_SEED_PLACEHOLDER_32B" 
        return hmac.new(master_seed, did.encode(), hashlib.sha256).digest()

    def _capture_raw_finger(self, wait_for_release=True, timeout_sec=15):
        """Wait for finger press, capture, and optionally wait for release."""
        start_time = time.time()
        while not self.sensor.is_finger_pressed():
            if self._cancel_flag: return None
            if time.time() - start_time > timeout_sec:
                logger.warning("Capture timed out waiting for press.")
                return None
            import gevent; gevent.sleep(0.1)
        
        time.sleep(0.3)
        try:
            raw_tensor = self.sensor.capture(self.finger_pipeline)
        except Exception as e:
            logger.error(f"Capture error: {e}")
            return None
            
        if wait_for_release:
            start_release = time.time()
            while self.sensor.is_finger_pressed():
                if self._cancel_flag: break
                if time.time() - start_release > timeout_sec:
                    logger.warning("Capture timed out waiting for release.")
                    break
                import gevent; gevent.sleep(0.1)
        return raw_tensor

    def get_system_health(self):
        """Comprehensive health check for Kiosk operations."""
        health = {
            "sensor": "offline", "camera": "offline",
            "network": "offline", "ipfs": "offline", "validator_count": 0
        }
        if self.hardware_available and self.sensor and self.sensor.connected:
            health["sensor"] = "online"
        if hasattr(self, '_cam') and self._cam.is_opened:
            health["camera"] = "online"

        try:
            from web3 import Web3
            up_nodes = 0
            primary_online = False
            if self.agent and self.agent.w3:
                try:
                    if self.agent.w3.is_connected():
                        primary_online = True
                                                                        
                        up_nodes = self.agent.w3.net.peer_count + 1              
                except: pass

            if not primary_online:
                for url in self.rpc_nodes:
                    try:
                        w3 = Web3(Web3.HTTPProvider(url, request_kwargs={'timeout': 2}))
                        if w3.is_connected(): up_nodes += 1
                    except: pass
            
            health["validator_count"] = up_nodes
            health["quorum"] = "online" if up_nodes >= 3 else "offline"
            if primary_online: health["network"] = "online"
            elif up_nodes > 0: health["network"] = "warning"
            else: health["network"] = "offline"
        except Exception as e:
            logger.warning(f"Network health check error: {e}")

        try:
             if self.agent and self.agent.ipfs:
                 self.agent.ipfs.id()
                 health["ipfs"] = "online"
        except Exception as e:
             logger.warning(f"IPFS health check failed: {e}")
             health["ipfs"] = "offline"
        
        return health

    def check_did_availability(self, did):
        try:
            if not did.startswith("did:ethr:0x"):
                return {"status": "error", "message": "Invalid DID format"}
            target_addr = did.split(":")[-1]
            if not self.registry_contract:
                return {"status": "error", "message": "Registry not connected"}
            existing_did, _, is_valid = self.registry_contract.functions.profiles(target_addr).call()
            if existing_did and len(existing_did) > 0:
                 return {"status": "taken", "message": "DID already registered."}
            return {"status": "available"}
        except Exception as e:
            logger.error(f"DID Check Failed: {e}")
            return {"status": "error", "message": str(e)}

    def enroll(self, user_id, name, target_did, email=None, college=None, department=None, position=None):
        if self.busy:
            return {"status": "error", "message": "System is busy with another operation."}
        if not self.hardware_available:
            raise SecurityError("Enrollment requires biometric hardware.")
        
        self.busy = True
        self._cancel_flag = False
        logger.info(f">>> [BACKEND] Starting Enrollment for User ID: {user_id}, Name: {name}")
        
        instr.start_timer(user_id, "enroll_e2e")
        instr.start_session(user_id)
        instr.set_phase("PRE_CHECK")
        instr.start_timer(user_id, "enroll_pre_check")
        
        try:
                                              
            instr.stop_timer(user_id, "enroll_pre_check")
            instr.set_phase("FINGERPRINT_CAPTURE")
            instr.start_timer(user_id, "enroll_fp_capture")
            
            self.sensor.set_led(True)
            raw_samples = []
            try:
                for i in range(3):
                    import eel
                    eel.update_kiosk_step("PRESS_FINGER", i+1, 3)
                    start_press = time.time()
                    while not self.sensor.is_finger_pressed():
                        if self._cancel_flag:
                            logger.info(" Enrollment cancelled during finger press wait.")
                            return {"status": "cancelled", "message": "Operation cancelled by user"}
                        if time.time() - start_press > 12:                  
                            return {"status": "error", "message": "Enrollment timed out waiting for finger press."}
                        import gevent; gevent.sleep(0.1)
                    
                    time.sleep(0.5)
                    eel.update_kiosk_step("CAPTURING", i+1, 3)
                    sample = self._capture_raw_finger(wait_for_release=False)
                    if sample is None: raise RuntimeError(f"FP Sample {i+1} failed.")
                    raw_samples.append(sample)
                    
                    eel.update_kiosk_step("LIFT_FINGER", i+1, 3)
                    start_lift = time.time()
                    while self.sensor.is_finger_pressed():
                        if self._cancel_flag:
                            logger.info(" Enrollment cancelled during finger lift wait.")
                            return {"status": "cancelled", "message": "Operation cancelled by user"}
                        if time.time() - start_lift > 4: break                  
                        import gevent; gevent.sleep(0.1)
                    time.sleep(0.5)
            finally:
                self.sensor.set_led(False)
            
            instr.stop_timer(user_id, "enroll_fp_capture")                 
            
            instr.set_phase("AI_EXTRACTION")
            instr.start_timer(user_id, "enroll_ai_processing")

            k_v = secrets.token_bytes(16)
            fp_record = self.finger_pipeline.enroll_fuzzy(raw_samples, k_v, user_did=target_did)
            fp_record_json = {'stl_helper': fp_record['stl_helper'], 'debug_anchor': fp_record['debug_anchor']}

            k_s = self.key_manager.generate_key()
            encrypted_ks_record = self.vault.encrypt_stl_key(k_v, k_s)

            from sensor import CameraSensor
            if not hasattr(self, '_cam'): self._cam = CameraSensor()
            if not self._cam.is_opened: self._cam.connect()
            
            instr.stop_timer(user_id, "enroll_ai_processing")                    

            try:
                                       
                instr.set_phase("FACE_CAPTURE")
                instr.start_timer(user_id, "enroll_face_capture")
                self._cam.set_active(True)
                aligned_frames = 0
                start_align = time.time()
                while True:
                    if self._cancel_flag:
                        logger.info(" Enrollment cancelled during face alignment.")
                        return {"status": "cancelled", "message": "Operation cancelled by user"}
                    if time.time() - start_align > 25:                  
                        return {"status": "error", "message": "Face alignment timed out."}
                    ret, frame = self._cam.read()
                    if not ret: break
                    det_res = self.face_preproc.process(frame)
                    status_signal = 0
                    if det_res["status"] == "ok":
                        h, w = frame.shape[:2]
                        x1, y1, x2, y2 = det_res["bbox"]
                        if ((y2-y1)/h) > 0.35 and abs(((x1+x2)/2)-w/2) < (w*0.15):
                            status_signal = 2; aligned_frames += 1
                        else: status_signal = 1; aligned_frames = 0
                    else: aligned_frames = 0

                    small_frame = cv2.resize(frame, (480, 360))
                    _, buffer = cv2.imencode('.jpg', small_frame, [cv2.IMWRITE_JPEG_QUALITY, 60])
                    import eel
                    eel.update_camera_frame(base64.b64encode(buffer).decode('utf-8'))
                    eel.update_kiosk_step("FACE_ALIGN", 0, status_signal)
                    if aligned_frames >= 12: break
                    import gevent; gevent.sleep(0)

                for countdown in range(3, 0, -1):
                    if self._cancel_flag: return {"status": "cancelled", "message": "Operation cancelled by user"}
                    eel.update_kiosk_step("FACE_COUNTDOWN", countdown, 3)
                    start_tick = time.time()
                    while time.time() - start_tick < 1.0:
                        if self._cancel_flag:
                            logger.info(" Enrollment cancelled during countdown.")
                            return {"status": "cancelled", "message": "Operation cancelled by user"}
                        ret, frame = self._cam.read()
                        if not ret: break
                        det_res = self.face_preproc.process(frame)
                        current_aligned = False
                        if det_res["status"] == "ok":
                            h, w = frame.shape[:2]
                            x1, y1, x2, y2 = det_res["bbox"]
                            if ((y2-y1)/h) > 0.35 and abs(((x1+x2)/2)-w/2) < (w*0.15): current_aligned = True
                        if not current_aligned:
                            eel.update_kiosk_step("FACE_ABORT", 0, 0)
                            return {"status": "error", "message": "Face alignment lost."}
                        small_frame = cv2.resize(frame, (480, 360))
                        _, buffer = cv2.imencode('.jpg', small_frame, [cv2.IMWRITE_JPEG_QUALITY, 60])
                        eel.update_camera_frame(base64.b64encode(buffer).decode('utf-8'))
                        gevent.sleep(0)

                eel.update_kiosk_step("PROCESSING", 0, 0)
                instr.stop_timer(user_id, "enroll_face_capture")                   
                
                instr.set_phase("IPFS_ANCHORING")
                instr.start_timer(user_id, "enroll_anchoring")
                
                ret, frame_bgr = self._cam.read()
                if not ret: raise RuntimeError("Camera failed.")
                face_res = self.face_preproc.process(frame_bgr)
                if face_res["status"] != "ok": raise RuntimeError("Face not detected.")
                pad = self.pad_runtime.predict(face_res["pad_output"])
                if not pad.decision: raise SecurityError("Attack detected.")
                face_emb = self.face_embedder.forward(face_res["embedder_output"], k_s)
                
                profile_cid = self.agent.create_profile(
                    user_data={"did": target_did, "name": name, "user_id": user_id},
                    vault_data=fp_record_json, face_data=encrypted_ks_record,
                    face_template=face_emb.tolist(),
                    metadata={"email": email or "", "college": college or "", "department": department or "", "position": position or ""}
                )
                
                instr.set_phase("BLOCKCHAIN_ANCHORING")
                receipt = self.agent.anchor_identity(
                    self.bridge.registry_contract, self.agent.account, self.agent.account.key,
                    profile_cid, target_addr=target_did.split(":")[-1], target_did=target_did
                )
                if receipt and receipt['status'] == 1:
                    instr.stop_timer(user_id, "enroll_anchoring")
                    instr.stop_timer(user_id, "enroll_e2e")
                    instr.stop_session()
                    instr.log_success(user_id, "enrollment", metadata=f"did={target_did}")
                    return {"status": "ok", "profile_cid": profile_cid, "metadata_cid": "INCLUDED_IN_PROFILE"}
                else: raise RuntimeError("Blockchain anchoring failed.")
            finally:
                self._cam.set_active(False)
        except Exception as e:
            instr.stop_session()
            instr.log_failure(user_id, "enrollment", str(e))
            raise e
        finally:
            self.busy = False
            self._cancel_flag = False

    def reissue_identity(self, user_id, name, existing_did, target_addr, user_signature, email=None, college=None, department=None, position=None):
        """Captures fresh biometrics and reissues the user's identity on-chain using a pre-signed voucher."""
        if self.busy:
            return {"status": "error", "message": "System is busy with another operation."}
        if not self.hardware_available:
            raise SecurityError("Reissuance requires biometric hardware.")
        
        self.busy = True
        self._cancel_flag = False
        logger.info(f">>> [BACKEND] Starting Reissuance for User ID: {user_id}, Name: {name}, DID: {existing_did}")
        
        instr.start_timer(user_id, "reissue_e2e")
        instr.start_session(user_id)
        instr.set_phase("PRE_CHECK")
        
        try:
                                              
            instr.set_phase("FINGERPRINT_CAPTURE")
            
            self.sensor.set_led(True)
            raw_samples = []
            try:
                for i in range(3):
                    import eel
                    eel.update_kiosk_step("PRESS_FINGER", i+1, 3)
                    start_press = time.time()
                    while not self.sensor.is_finger_pressed():
                        if self._cancel_flag:
                            logger.info(" Reissuance cancelled during finger press wait.")
                            return {"status": "cancelled", "message": "Operation cancelled by user"}
                        if time.time() - start_press > 12:
                            return {"status": "error", "message": "Reissuance timed out waiting for finger press."}
                        import gevent; gevent.sleep(0.1)
                    
                    time.sleep(0.5)
                    eel.update_kiosk_step("CAPTURING", i+1, 3)
                    sample = self._capture_raw_finger(wait_for_release=False)
                    if sample is None: raise RuntimeError(f"FP Sample {i+1} failed.")
                    raw_samples.append(sample)
                    
                    eel.update_kiosk_step("LIFT_FINGER", i+1, 3)
                    start_lift = time.time()
                    while self.sensor.is_finger_pressed():
                        if self._cancel_flag:
                            logger.info(" Reissuance cancelled during finger lift wait.")
                            return {"status": "cancelled", "message": "Operation cancelled by user"}
                        if time.time() - start_lift > 4: break
                        import gevent; gevent.sleep(0.1)
                    time.sleep(0.5)
            finally:
                self.sensor.set_led(False)
            
            instr.set_phase("AI_EXTRACTION")
            
            k_v = secrets.token_bytes(16)
            fp_record = self.finger_pipeline.enroll_fuzzy(raw_samples, k_v, user_did=existing_did)
            fp_record_json = {'stl_helper': fp_record['stl_helper'], 'debug_anchor': fp_record['debug_anchor']}

            k_s = self.key_manager.generate_key()
            encrypted_ks_record = self.vault.encrypt_stl_key(k_v, k_s)

            from sensor import CameraSensor
            if not hasattr(self, '_cam'): self._cam = CameraSensor()
            if not self._cam.is_opened: self._cam.connect()
            
            try:
                                       
                instr.set_phase("FACE_CAPTURE")
                self._cam.set_active(True)
                aligned_frames = 0
                start_align = time.time()
                while True:
                    if self._cancel_flag:
                        logger.info(" Reissuance cancelled during face alignment.")
                        return {"status": "cancelled", "message": "Operation cancelled by user"}
                    if time.time() - start_align > 25:
                        return {"status": "error", "message": "Face alignment timed out."}
                    ret, frame = self._cam.read()
                    if not ret: break
                    det_res = self.face_preproc.process(frame)
                    status_signal = 0
                    if det_res["status"] == "ok":
                        h, w = frame.shape[:2]
                        x1, y1, x2, y2 = det_res["bbox"]
                        if ((y2-y1)/h) > 0.35 and abs(((x1+x2)/2)-w/2) < (w*0.15):
                            status_signal = 2; aligned_frames += 1
                        else: status_signal = 1; aligned_frames = 0
                    else: aligned_frames = 0

                    small_frame = cv2.resize(frame, (480, 360))
                    _, buffer = cv2.imencode('.jpg', small_frame, [cv2.IMWRITE_JPEG_QUALITY, 60])
                    import eel
                    eel.update_camera_frame(base64.b64encode(buffer).decode('utf-8'))
                    eel.update_kiosk_step("FACE_ALIGN", 0, status_signal)
                    if aligned_frames >= 12: break
                    import gevent; gevent.sleep(0)

                for countdown in range(3, 0, -1):
                    if self._cancel_flag: return {"status": "cancelled", "message": "Operation cancelled by user"}
                    eel.update_kiosk_step("FACE_COUNTDOWN", countdown, 3)
                    start_tick = time.time()
                    while time.time() - start_tick < 1.0:
                        if self._cancel_flag:
                            logger.info(" Reissuance cancelled during countdown.")
                            return {"status": "cancelled", "message": "Operation cancelled by user"}
                        ret, frame = self._cam.read()
                        if not ret: break
                        det_res = self.face_preproc.process(frame)
                        current_aligned = False
                        if det_res["status"] == "ok":
                            h, w = frame.shape[:2]
                            x1, y1, x2, y2 = det_res["bbox"]
                            if ((y2-y1)/h) > 0.35 and abs(((x1+x2)/2)-w/2) < (w*0.15): current_aligned = True
                        if not current_aligned:
                            eel.update_kiosk_step("FACE_ABORT", 0, 0)
                            return {"status": "error", "message": "Face alignment lost."}
                        small_frame = cv2.resize(frame, (480, 360))
                        _, buffer = cv2.imencode('.jpg', small_frame, [cv2.IMWRITE_JPEG_QUALITY, 60])
                        eel.update_camera_frame(base64.b64encode(buffer).decode('utf-8'))
                        gevent.sleep(0)

                eel.update_kiosk_step("PROCESSING", 0, 0)
                
                instr.set_phase("IPFS_ANCHORING")
                
                ret, frame_bgr = self._cam.read()
                if not ret: raise RuntimeError("Camera failed.")
                face_res = self.face_preproc.process(frame_bgr)
                if face_res["status"] != "ok": raise RuntimeError("Face not detected.")
                pad = self.pad_runtime.predict(face_res["pad_output"])
                if not pad.decision: raise SecurityError("Attack detected.")
                face_emb = self.face_embedder.forward(face_res["embedder_output"], k_s)
                
                profile_cid = self.agent.create_profile(
                    user_data={"did": existing_did, "name": name, "user_id": user_id},
                    vault_data=fp_record_json, face_data=encrypted_ks_record,
                    face_template=face_emb.tolist(),
                    metadata={
                        "email": email or "", 
                        "college": college or "", 
                        "department": department or "", 
                        "position": position or ""
                    }
                )
                
                instr.set_phase("BLOCKCHAIN_ANCHORING")
                                                                    
                receipt = self.agent.reissue_user(
                    self.bridge.registry_contract, self.agent.account, self.agent.account.key,
                    target_addr, existing_did, profile_cid, user_signature
                )
                if receipt and receipt.status == 1:
                    instr.stop_timer(user_id, "reissue_e2e")
                    instr.stop_session()
                    instr.log_success(user_id, "reissuance", metadata=f"did={existing_did}")
                    return {"status": "ok", "profile_cid": profile_cid, "message": "Identity Reissued Successfully"}
                else: raise RuntimeError("Blockchain reissuance failed.")
            finally:
                self._cam.set_active(False)
        except Exception as e:
            instr.stop_session()
            instr.log_failure(user_id, "reissuance", str(e))
            raise e
        finally:
            self.busy = False
            self._cancel_flag = False

    def verify(self, claimed_user_addr):
        if self.busy: raise RuntimeError("System busy.")
        if not self.hardware_available: raise SecurityError("Hardware required.")
        self.busy = True
        self._cancel_flag = False
        
        instr.start_timer(claimed_user_addr, "verify_e2e")
        instr.start_session(claimed_user_addr)
        
        try:
                             
            instr.set_phase("CHAIN_LOOKUP")
            instr.start_timer(claimed_user_addr, "verify_chain_lookup")
            
            if isinstance(claimed_user_addr, str) and claimed_user_addr.startswith("did:ethr:0x"):
                claimed_user_addr = claimed_user_addr.split(":")[-1]
                
            checksum_addr = self.agent.w3.to_checksum_address(claimed_user_addr)
            did, profile_cid, active = self.bridge.registry_contract.functions.profiles(checksum_addr).call()
            if not active or not profile_cid: raise ValueError("User not enrolled or invalid.")
            profile = self.agent.resolve_profile(profile_cid, user_did=did)
            if not profile: raise RuntimeError("IPFS resolution failed.")
            instr.stop_timer(claimed_user_addr, "verify_chain_lookup")
            
            instr.set_phase("BIOMETRIC_VERIFY")
            instr.start_timer(claimed_user_addr, "verify_biometrics")
            
            self.sensor.set_led(True)
            user_name = profile['identity']['name']
            try:
                import eel
                eel.update_kiosk_step("PRESS_FINGER", 1, 1)
                start_p = time.time()
                while not self.sensor.is_finger_pressed():
                    if self._cancel_flag:
                        logger.info(" Verification cancelled during finger press wait.")
                        return {"status": "cancelled", "message": "Operation cancelled by user"}
                    if time.time() - start_p > 12: raise RuntimeError("Timeout.")                  
                    import gevent; gevent.sleep(0.1)
                time.sleep(0.5)
                eel.update_kiosk_step("CAPTURING", 1, 1)
                raw_fp = self._capture_raw_finger(wait_for_release=False)
                if raw_fp is None: raise RuntimeError("FP failed.")
                eel.update_kiosk_step("LIFT_FINGER", 1, 1)
                start_l = time.time()
                while self.sensor.is_finger_pressed():
                    if self._cancel_flag:
                        logger.info(" Verification cancelled during finger lift wait.")
                        return {"status": "cancelled", "message": "Operation cancelled by user"}
                    if time.time() - start_l > 4: break                  
                    import gevent; gevent.sleep(0.1)
                self.sensor.set_led(False)

                fp_vault = profile['security']["fingerprint_vault"]
                debug_anchor = fp_vault.get("debug_anchor", [])
                if isinstance(debug_anchor, dict):
                    debug_anchor = list(debug_anchor.values()) if debug_anchor else [0.0]                            
                stored_fp = {'stl_helper': fp_vault["stl_helper"], 'debug_anchor': debug_anchor}
                v_res = self.finger_pipeline.verify_fuzzy(raw_fp, stored_fp, user_did=did)
                
                if isinstance(v_res, dict):
                    k_v = v_res.get('secret')
                elif isinstance(v_res, (bytes, bytearray)):
                    k_v = v_res                              
                else:
                    k_v = None
                
                if k_v is None: raise SecurityError("Fingerprint mismatch.")
                k_s = self.vault.decrypt_stl_key(k_v, profile['security']["encrypted_keys"])
                
                if not hasattr(self, '_cam'): from sensor import CameraSensor; self._cam = CameraSensor()
                if not self._cam.is_opened: self._cam.connect()
                try:
                    self._cam.set_active(True)
                    aligned_frames = 0; start_a = time.time()
                    while True:
                        if self._cancel_flag:
                            logger.info(" Verification cancelled during face alignment.")
                            return {"status": "cancelled", "message": "Operation cancelled by user"}
                        if time.time() - start_a > 25: raise RuntimeError("Timeout.")                  
                        ret, frame = self._cam.read()
                        if not ret: break
                        det = self.face_preproc.process(frame)
                        status = 0
                        if det["status"] == "ok":
                            h, w = frame.shape[:2]; x1, y1, x2, y2 = det["bbox"]
                            if ((y2-y1)/h) > 0.35 and abs(((x1+x2)/2)-w/2) < (w*0.15): status = 2; aligned_frames += 1
                            else: status = 1; aligned_frames = 0
                        else: aligned_frames = 0
                        small = cv2.resize(frame, (480, 360)); _, buf = cv2.imencode('.jpg', small, [cv2.IMWRITE_JPEG_QUALITY, 60])
                        eel.update_camera_frame(base64.b64encode(buf).decode('utf-8'))
                        eel.update_kiosk_step("FACE_ALIGN", 0, status)
                        if aligned_frames >= 12: break
                        import gevent; gevent.sleep(0)

                    eel.update_kiosk_step("PROCESSING", 0, 0)
                    ret, frame_bgr = self._cam.read()
                    face_res = self.face_preproc.process(frame_bgr)
                    pad = self.pad_runtime.predict(face_res["pad_output"])
                    if not pad.decision: raise SecurityError("Attack detected.")
                    fresh_face_emb = self.face_embedder.forward(face_res["embedder_output"], k_s)
                    
                    template = profile['security'].get("face_template")
                    
                    try:
                                                          
                        probe_arr = np.array(template, dtype=np.float32)
                        dist = utils.normalised_distance(probe_arr, fresh_face_emb)
                    except Exception as e:
                        logger.error(f" BIOMETRIC COMPARISON FAILED: Template is malformed or invalid type ({type(template)}). Error: {e}")
                                                                                                  
                        if isinstance(template, dict):
                             raise SecurityError("Face template in profile is corrupted (dictionary found where vector expected). Reissuance required.")
                        raise SecurityError(f"Biometric Processing Error: {e}")
                        
                    instr.stop_timer(claimed_user_addr, "verify_biometrics")
                    
                    logger.info(f"Face Distance: {dist:.6f} (Threshold: {self.face_config.embedder.thresh:.6f})")
                    if dist <= self.face_config.embedder.thresh:
                                    
                        instr.set_phase("BLOCKCHAIN_LOGGING")
                        instr.start_timer(claimed_user_addr, "verify_logging")
                        res = self.bridge.process_attendance_event(claimed_user_addr, user_name, "PROOFOFWORK", True, "SUCCESS", "SESSION_KEY")
                        instr.stop_timer(claimed_user_addr, "verify_logging")
                        instr.stop_timer(claimed_user_addr, "verify_e2e")
                        instr.stop_session()
                        instr.log_success(claimed_user_addr, "verification", metadata=f"dist={dist:.4f}")
                        return res
                    else: raise SecurityError("Face mismatch.")
                finally: self._cam.set_active(False)
            except SecurityError as se:
                logger.warning(f"Authentication Failure: {se}")
                                                 
                try:
                    self.bridge.process_attendance_event(claimed_user_addr, user_name, "N/A", False, "FAILED", str(se))
                except Exception as e:
                    logger.error(f"Failed to log failure: {e}")
                instr.log_failure(claimed_user_addr, "verification", str(se))
                instr.stop_session()
                raise se
            finally:
                self.sensor.set_led(False)
        except Exception as e:
            instr.stop_session()
            instr.log_failure(claimed_user_addr, "verification", str(e))
            raise e
        finally:
            self.busy = False
            self._cancel_flag = False
            try:
                if 'k_v' in locals(): del k_v
                if 'k_s' in locals(): del k_s
            except: pass

    def verify_by_did(self, did):
        """Helper to verify using a DID instead of a claim address."""
        if not did.startswith("did:ethr:0x"):
            return {"status": "error", "message": "Invalid DID format"}
        target_addr = did.split(":")[-1]
        return self.verify(target_addr)

    def scan_qr(self, timeout=30):
        """Scans for a QR code using the active camera."""
        if self.busy: raise RuntimeError("System busy.")
        self.busy = True
        self._cancel_flag = False
        try:
            if not hasattr(self, '_cam'): from sensor import CameraSensor; self._cam = CameraSensor()
            if not self._cam.is_opened: self._cam.connect()
            
            logger.info(" Starting QR Scan...")
            self._cam.set_active(True)
            
            qr_detector = cv2.QRCodeDetector()
            start_time = time.time()
            
            import eel
            
            while True:
                if self._cancel_flag:
                    logger.info(" QR Scan Cancelled by User.")
                    raise InterruptedError("Operation check failed.")
                
                if time.time() - start_time > timeout:
                    raise TimeoutError("QR Scan timed out.")
                
                ret, frame = self._cam.read()
                if not ret: break
                
                data, bbox, _ = qr_detector.detectAndDecode(frame)
                
                if bbox is not None:
                    n = len(bbox)
                    for j in range(n):
                        cv2.line(frame, tuple(bbox[j][0].astype(int)), tuple(bbox[(j+1) % n][0].astype(int)), (0, 255, 0), 3)
                    
                    if data:
                        logger.info(f" QR Detected: {data}")
                        return data

                small = cv2.resize(frame, (480, 360))
                _, buf = cv2.imencode('.jpg', small, [cv2.IMWRITE_JPEG_QUALITY, 60])
                eel.update_camera_frame(base64.b64encode(buf).decode('utf-8'))
                
                import gevent; gevent.sleep(0)
                
        except Exception as e:
            logger.error(f"QR Scan Error: {e}")
            raise e
        finally:
            self._cam.set_active(False)
            self.busy = False

if __name__ == "__main__":
    import argparse, sys
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")
    enroll_parser = subparsers.add_parser("enroll")
    enroll_parser.add_argument("--name", required=True); enroll_parser.add_argument("--user_id", required=True); enroll_parser.add_argument("--did", required=True)
    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("--address", required=True)
    args = parser.parse_args()
    if args.command == "enroll":
        try:
            global backend_instance
            backend = Backend()
            backend_instance = backend
            Backend._expose_cancellation()
            success = backend.enroll(args.user_id, args.name, args.did)
            if success: logger.info("Enrollment Success")
        except Exception as e: logger.error(f"Enrollment Failed: {e}"); sys.exit(1)
    elif args.command == "verify":
        try:
            backend = Backend()
            cid = backend.verify(args.address)
            if cid: logger.info(f"Verification Success: {cid}")
        except Exception as e: logger.error(f"Verification Failed: {e}"); sys.exit(1)
