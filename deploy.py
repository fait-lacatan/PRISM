import yaml
import json
import logging
import os
from prism_sdk.agent import IdentityAgent

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

DEFAULT_RPC_URL = "http://192.168.8.101:8545"
DEFAULT_CHAIN_ID = 1337
DEFAULT_IPFS_API = "/ip4/127.0.0.1/tcp/5001"
MASTER_CONFIG_PATH = "blockchain/master.yaml"
ARTIFACTS_DIR = "blockchain/build"

def load_network_config():
    """Load network config from yaml or return defaults."""
    config = {
        'rpc_url': DEFAULT_RPC_URL,
        'chain_id': DEFAULT_CHAIN_ID,
        'ipfs_api': DEFAULT_IPFS_API
    }
    if os.path.exists(MASTER_CONFIG_PATH):
        try:
            with open(MASTER_CONFIG_PATH, 'r') as f:
                data = yaml.safe_load(f) or {}
                network = data.get('network', {})
                identities = data.get('identities', {})
                                                                                    
                if network:
                    config.update(network)
                if identities:
                    config.update(identities)
        except Exception as e:
            logger.warning(f"Failed to read {MASTER_CONFIG_PATH}, using defaults: {e}")
    return config

def load_artifact(contract_name):
    """Load ABI and Bytecode for a given contract from JSON artifact."""
    artifact_path = os.path.join(ARTIFACTS_DIR, f"{contract_name}.json")

    if not os.path.exists(artifact_path):
        raise FileNotFoundError(f"Artifact for {contract_name} not found at {artifact_path}")

    try:
        with open(artifact_path, "r") as f:
            data = json.load(f)
            return data["abi"], data["bytecode"]
    except Exception as e:
        raise RuntimeError(f"Failed to load artifacts for {contract_name}: {e}")

def deploy_contract(agent, name, abi, bytecode, constructor_args=None, chain_id=DEFAULT_CHAIN_ID):
    """Deploy a single contract and return the receipt."""
    if constructor_args is None:
        constructor_args = []
    
    deployer = agent.account
    Contract = agent.w3.eth.contract(abi=abi, bytecode=bytecode)
    
    try:
        current_nonce = agent.w3.eth.get_transaction_count(deployer.address)
        
        construct_txn = Contract.constructor(*constructor_args).build_transaction({
            'from': deployer.address,
            'nonce': current_nonce,
            'gas': 10000000,
            'gasPrice': 0,
            'chainId': chain_id
        })
        
        signed = agent.w3.eth.account.sign_transaction(construct_txn, deployer.key)
        tx_hash = agent.w3.eth.send_raw_transaction(signed.raw_transaction)
        logger.info(f"Submitted deployment for {name}, hash: {tx_hash.hex()}")
        
        receipt = agent.w3.eth.wait_for_transaction_receipt(tx_hash)
        if receipt.status == 1:
            logger.info(f"{name} deployed at: {receipt.contractAddress}")
            return receipt
        else:
            raise RuntimeError(f"Deployment for {name} failed (status 0)")
            
    except Exception as e:
        logger.error(f"Error deploying {name}: {e}")
        raise

def grant_admin_privileges(agent, registry_addr, registry_abi):
    """
    Bootstraps the initial ACL.
    The Deployer (Owner) assigns ITSELF as Enroller, Recorder, and Revoker.
    This ensures the 'admin agent' can perform all actions.
    """
    logger.info(" Bootstrapping Admin Privileges for Deployer...")
    deployer_addr = agent.account.address
    registry = agent.w3.eth.contract(address=registry_addr, abi=registry_abi)
    
    agent.set_enroll_auth(registry, agent.account, agent.account.key, deployer_addr, True)
    
    agent.set_remote_record_auth(registry, agent.account, agent.account.key, deployer_addr, True)
    
    agent.set_revoke_auth(registry, agent.account, agent.account.key, deployer_addr, True)
    
    logger.info(" Admin Privileges Granted to Deployer.")

def redeploy():
    network_config = load_network_config()
    rpc_url = network_config.get('rpc_url', DEFAULT_RPC_URL)
    chain_id = network_config.get('chain_id', DEFAULT_CHAIN_ID)

    try:
                                                    
        admin_key = network_config.get('admin_key_path')
        
        logger.info(f"Initializing IdentityAgent with RPC: {rpc_url}")
        
        if admin_key and os.path.exists(admin_key):
             agent = IdentityAgent(key_path=admin_key)
        else:
                                                     
             genesis_key = "storage/keys/genesis_deployer.key"
             if os.path.exists(genesis_key):
                 logger.info(f"Using Genesis Key: {genesis_key}")
                 agent = IdentityAgent(key_path=genesis_key)
             else:
                 logger.warning("No admin key found! Generating a random one (unfunded).")
                 agent = IdentityAgent() 
             
        deployer = agent.account
        logger.info(f"Using Deployer Account: {deployer.address}")

        reg_abi, reg_bin = load_artifact("Registry")
        reg_receipt = deploy_contract(agent, "Registry", reg_abi, reg_bin, chain_id=chain_id)
        
        perm_receipt = None
        perm_abi, perm_bin = load_artifact("Permissions")
        perm_receipt = deploy_contract(agent, "Permissions", perm_abi, perm_bin, chain_id=chain_id)
        logger.info(" Permissions contract deployed for node management")

        logger.info(" Linking Registry and Permissions contracts...")
        
        reg_contract = agent.w3.eth.contract(address=reg_receipt.contractAddress, abi=reg_abi)
        perm_contract = agent.w3.eth.contract(address=perm_receipt.contractAddress, abi=perm_abi)
        
        nonce = agent.w3.eth.get_transaction_count(deployer.address)
        tx1 = reg_contract.functions.setPermissionsAddress(perm_receipt.contractAddress).build_transaction({
            'from': deployer.address, 'nonce': nonce, 'gas': 100000, 'gasPrice': 0, 'chainId': chain_id
        })
        signed1 = agent.w3.eth.account.sign_transaction(tx1, deployer.key)
        tx_hash1 = agent.w3.eth.send_raw_transaction(signed1.raw_transaction)
        agent.w3.eth.wait_for_transaction_receipt(tx_hash1)
        
        nonce2 = agent.w3.eth.get_transaction_count(deployer.address)
        tx2 = perm_contract.functions.setRegistryAddress(reg_receipt.contractAddress).build_transaction({
            'from': deployer.address, 'nonce': nonce2, 'gas': 100000, 'gasPrice': 0, 'chainId': chain_id
        })
        signed2 = agent.w3.eth.account.sign_transaction(tx2, deployer.key)
        tx_hash2 = agent.w3.eth.send_raw_transaction(signed2.raw_transaction)
        agent.w3.eth.wait_for_transaction_receipt(tx_hash2)
        
        logger.info(" Initialization Guard bypassed: Contracts linked successfully.")

        grant_admin_privileges(agent, reg_receipt.contractAddress, reg_abi)

        try:
            kiosk_id_path = os.path.join("provision", "dist", "kiosk_identities.json")
            if os.path.exists(kiosk_id_path):
                with open(kiosk_id_path, "r") as f:
                    kiosk_identities = json.load(f)
                
                logger.info(f" Found {len(kiosk_identities)} Kiosk Identities. Authorizing...")
                
                for kid, data in kiosk_identities.items():
                    kiosk_addr = data['kiosk_address']
                    
                    enode_url = data.get('enode')
                    if enode_url:
                        try:
                            nonce_perm = agent.w3.eth.get_transaction_count(deployer.address)
                            tx_perm = perm_contract.functions.addNode(enode_url).build_transaction({
                                'from': deployer.address, 'nonce': nonce_perm, 'gas': 200000, 'gasPrice': 0, 'chainId': chain_id
                            })
                            signed_perm = agent.w3.eth.account.sign_transaction(tx_perm, deployer.key)
                            tx_hash_perm = agent.w3.eth.send_raw_transaction(signed_perm.raw_transaction)
                            agent.w3.eth.wait_for_transaction_receipt(tx_hash_perm)
                            logger.info(f" [+] Consensus Node Added: {enode_url[:30]}...")
                            
                            from eth_utils import keccak
                            enode_hash = keccak(text=enode_url)
                            
                            nonce_map = agent.w3.eth.get_transaction_count(deployer.address)
                            tx_map = reg_contract.functions.registerKioskEnode(kiosk_addr, enode_hash).build_transaction({
                                'from': deployer.address, 'nonce': nonce_map, 'gas': 200000, 'gasPrice': 0, 'chainId': chain_id
                            })
                            signed_map = agent.w3.eth.account.sign_transaction(tx_map, deployer.key)
                            tx_hash_map = agent.w3.eth.send_raw_transaction(signed_map.raw_transaction)
                            agent.w3.eth.wait_for_transaction_receipt(tx_hash_map)
                            logger.info(f" [+] Kiosk Wallet Mapped to Consensus Identity")

                        except Exception as inner_e:
                            logger.warning(f"Failed to add consensus node / map identity for {kid}: {inner_e}")

                    perms = agent.check_permissions(reg_contract, kiosk_addr)
                    
                    if not perms.get('canRecord', False):
                        agent.set_kiosk_record_auth(reg_contract, agent.account, agent.account.key, kiosk_addr, True)
                    if not perms.get('canEnroll', False):
                        agent.set_enroll_auth(reg_contract, agent.account, agent.account.key, kiosk_addr, True)
                        
                logger.info(" All Kiosk Nodes Authorized.")
            else:
                logger.warning(f" {kiosk_id_path} not found. Kiosks will NOT be authorized automatically.")
        except Exception as e:
            logger.error(f"Failed to auto-authorize kiosks: {e}")

        att_abi, att_bin = load_artifact("Attendance")
                                                          
        att_receipt = deploy_contract(agent, "Attendance", att_abi, att_bin, constructor_args=[reg_receipt.contractAddress], chain_id=chain_id)

        update_config(reg_receipt.contractAddress, att_receipt.contractAddress, 
                     perm_receipt.contractAddress if perm_receipt else None, network_config)

    except Exception as e:
        logger.critical(f"Deployment process failed: {e}")
                                                             
        raise

def update_config(reg_addr, att_addr, perm_addr, network_config):
    try:
        data = {}
        if os.path.exists(MASTER_CONFIG_PATH):
            with open(MASTER_CONFIG_PATH, 'r') as f:
                data = yaml.safe_load(f) or {}

        if 'contracts' not in data: data['contracts'] = {}
        if 'network' not in data: data['network'] = {}

        data['contracts']['registry'] = {'address': reg_addr, 'abi_path': 'blockchain/build/Registry.json'}
        data['contracts']['attendance'] = {'address': att_addr, 'abi_path': 'blockchain/build/Attendance.json'}
        
        if perm_addr:
            data['contracts']['permissions'] = {'address': perm_addr, 'abi_path': 'blockchain/build/Permissions.json'}
        
        data['network'].update(network_config)

        with open(MASTER_CONFIG_PATH, 'w') as f:
            yaml.dump(data, f)
        
        logger.info(f"Configuration updated in {MASTER_CONFIG_PATH}")

    except Exception as e:
        logger.error(f"Failed to update config file: {e}")
        raise

if __name__ == "__main__":
    redeploy()