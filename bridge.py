import json
import yaml
import os
import logging
import time
from prism_sdk.agent import IdentityAgent

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class LedgerBridge:
    def __init__(self, config_path="blockchain/master.yaml"):
                                                                                                          
        if not os.path.isabs(config_path):
            base_dir = os.path.dirname(os.path.abspath(__file__))
            config_path = os.path.join(base_dir, config_path)
            
        self.agent = IdentityAgent(config_path=config_path)
        
        self.config = self._load_config(config_path)
        
        registry_config = self.config.get('contracts', {}).get('registry', {})
        self.registry_address = registry_config.get('address')
        reg_abi_path = registry_config.get('abi_path')

        attendance_config = self.config.get('contracts', {}).get('attendance', {})
        self.attendance_address = attendance_config.get('address')
        att_abi_path = attendance_config.get('abi_path')
        
        if not self.registry_address or not reg_abi_path:
            logger.error("Registry address or ABI path missing in config.")
            raise ValueError("Invalid configuration: Missing Registry details.")

        permissions_config = self.config.get('contracts', {}).get('permissions', {})
        self.permissions_address = permissions_config.get('address')
        perm_abi_path = permissions_config.get('abi_path')

        try:
                                             
            if not os.path.isabs(reg_abi_path):
                reg_abi_path = os.path.join(os.path.dirname(__file__), reg_abi_path)
                
            with open(reg_abi_path, "r") as f:
                self.registry_abi = json.load(f)["abi"]                                       
                
            self.registry_contract = self.agent.w3.eth.contract(
                address=self.registry_address, 
                abi=self.registry_abi
            )
            logger.info(f"LedgerBridge connected to Registry at {self.registry_address}")

            if not os.path.isabs(att_abi_path):
                att_abi_path = os.path.join(os.path.dirname(__file__), att_abi_path)

            with open(att_abi_path, "r") as f:
                self.attendance_abi = json.load(f)["abi"]

            self.attendance_contract = self.agent.w3.eth.contract(
                address=self.attendance_address,
                abi=self.attendance_abi
            )
            logger.info(f"LedgerBridge connected to Attendance at {self.attendance_address}")

            if self.permissions_address and perm_abi_path:
                if not os.path.isabs(perm_abi_path):
                    perm_abi_path = os.path.join(os.path.dirname(__file__), perm_abi_path)
                
                with open(perm_abi_path, "r") as f:
                    self.permissions_abi = json.load(f)["abi"]
                
                self.permissions_contract = self.agent.w3.eth.contract(
                    address=self.permissions_address,
                    abi=self.permissions_abi
                )
                logger.info(f"LedgerBridge connected to Permissions at {self.permissions_address}")
            
        except FileNotFoundError:
            logger.warning(f"Contract ABI not found. Anchoring may fail.")
        except Exception as e:
            logger.error(f"Failed to initialize contracts: {e}")

    def reload_contracts(self):
        """Re-instantiates contract objects with the current agent.w3 provider."""
        if not self.agent.w3: return
        
        try:
            self.registry_contract = self.agent.w3.eth.contract(
                address=self.registry_address, 
                abi=self.registry_abi
            )
            self.attendance_contract = self.agent.w3.eth.contract(
                address=self.attendance_address,
                abi=self.attendance_abi
            )
            if hasattr(self, 'permissions_address'):
                self.permissions_contract = self.agent.w3.eth.contract(
                    address=self.permissions_address,
                    abi=self.permissions_abi
                )
            logger.info("Contracts re-bound to new provider.")
        except Exception as e:
            logger.error(f"Contract reload failed: {e}")

    def _load_config(self, path):
        try:
            with open(path, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            logger.error(f"Configuration file not found at {path}")
            return {}

    def process_attendance_event(self, user_id, user_name, proof_hash, liveness_status, status="SUCCESS", error_type=None, session_key=None):
        """
        Coordinates the post-verification lifecycle: VC -> IPFS -> Quorum.
        Handles both SUCCESS and FAILURE events.
        """
        logger.info(f"Processing attendance event for {user_name} ({user_id}) - Status: {status}")

        session_signature = None
        if session_key and status == "SUCCESS":
             import hmac
             import hashlib
             session_signature = hmac.new(
                 session_key.encode(), 
                 proof_hash.encode(), 
                 hashlib.sha256
             ).hexdigest()

        if status == "SUCCESS":
                              
            vc = self.agent.sign_attendance_vc(
                user_id=user_id, 
                name=user_name, 
                proof_hash=proof_hash,
                liveness_status=liveness_status,
                session_sig=session_signature
            )
        else:
                                               
            vc = {
                "event": "Authentication_Failure",
                "timestamp": time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                "subject": user_id,
                "status": "FAILED"
            }

        logger.info("Pinning Event Data to IPFS...")
        info_cid = self.agent.upload_to_ipfs(vc)
        
        receipt = self.agent.log_attendance_on_chain(
            self.attendance_contract,
            user_id,               
            info_cid,                
            status,                                 
            self.agent.account,
            self.agent.account.key
        )
        
        if receipt and receipt['status'] == 1:
            logger.info(f"Event Recorded. CID: {info_cid} | Block: {receipt['blockNumber']}")
            return info_cid
        else:
            logger.error("Failed to anchor event on-chain.")
            raise RuntimeError("Blockchain logging failed.")