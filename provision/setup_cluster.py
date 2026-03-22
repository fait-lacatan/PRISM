import os
import json
import argparse
import secrets
import sys
from eth_account import Account
from eth_utils import encode_hex
import shutil
import rlp

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
sys.path.append(PROJECT_ROOT)

from prism.keys import KeyDerivationManager as DeviceKeyManager

DIST_DIR = os.path.join(SCRIPT_DIR, "dist")
QUORUM_PORT = 30303
GENESIS_PATH = os.path.join(PROJECT_ROOT, "blockchain", "genesis.json")
KIOSK_ID_FILE = os.path.join(SCRIPT_DIR, "dist", "kiosk_identities.json")

def generate_node_key():
    """Generates a random 32-byte private key for the node."""
    return secrets.token_bytes(32)

def generate_device_root_key():
    """Generates a random 32-byte device root key."""
    return secrets.token_bytes(32)

def derive_enode(private_key_bytes, ip, port):
    """Derives the enode URL from the private key (QBFT compatible)."""
    try:
        from eth_keys import keys
        priv = keys.PrivateKey(private_key_bytes)
        pub_key = priv.public_key.to_hex()[2:]
        return f"enode://{pub_key}@{ip}:{port}?discport=0"
    except ImportError:
        print("WARNING: 'eth_keys' not installed. Cannot derive public key for Enode.")
        exit(1)

def generate_swarm_key():
    """Generates a private IPFS Swarm Key."""
    key_bytes = secrets.token_bytes(32)
    return "/key/swarm/psk/1.0.0/\n/base16/\n" + key_bytes.hex()

def create_nginx_conf(node_idx):
    """Creates a basic Nginx config for termination."""
    return f"""
events {{}}
http {{
    server {{
        listen 80;
        listen 443 ssl;
        server_name node{node_idx}.local;

        ssl_certificate /etc/nginx/certs/self-signed.crt;
        ssl_certificate_key /etc/nginx/certs/self-signed.key;

        location /rpc {{
            proxy_pass http://quorum-node:8545;
        }}
        
        location /ipfs {{
            proxy_pass http://ipfs-node:8080;
        }}
    }}
}}
"""

def generate_qbft_extradata(validator_addresses):
    """Generate GoQuorum QBFT extradata for genesis.json."""
    vanity = b'\x00' * 32
    validators = [bytes.fromhex(addr[2:] if addr.startswith('0x') else addr) for addr in validator_addresses]
    istanbul_extra = [vanity, validators, [], b'', []]
    rlp_encoded = rlp.encode(istanbul_extra)
    return "0x" + rlp_encoded.hex()

def update_genesis(validator_addresses, kiosk_addresses):
    """Update genesis.json with QBFT validators and fund Kiosk wallets."""
    if not os.path.exists(GENESIS_PATH):
        print(f" Genesis file not found at {GENESIS_PATH}. Skipping update.")
        return

    with open(GENESIS_PATH, 'r') as f:
        genesis = json.load(f)
    
    extradata = generate_qbft_extradata(validator_addresses)
    genesis['extraData'] = extradata
    
    for addr in validator_addresses:
        if addr not in genesis['alloc']:
            genesis['alloc'][addr] = {"balance": "1000000000000000000000000000"} # 1B ETH

    for addr in kiosk_addresses:
        if addr not in genesis['alloc']:
            genesis['alloc'][addr] = {"balance": "1000000000000000000000000000"} # 1B ETH
            
    with open(GENESIS_PATH, 'w') as f:
        json.dump(genesis, f, indent=4)
    
    print(f" Updated genesis.json: {len(validator_addresses)} Validators, {len(kiosk_addresses)} Kiosks Funded")

def main():
    parser = argparse.ArgumentParser(description="Generate Cluster Config for Production Deployment")
    parser.add_argument("--ips", nargs="+", help="List of LAN IPs", required=True)
    args = parser.parse_args()

    if os.path.exists(DIST_DIR):
        print(f"Cleaning existing {DIST_DIR}...")
        shutil.rmtree(DIST_DIR)
    os.makedirs(DIST_DIR)

    node_entries = []
    node_configs = []
    kiosk_identities = {}

    print(f"--- Generating Configuration for {len(args.ips)} Nodes ---")

    # 1. Generate Keys & Enodes
    swarm_key = generate_swarm_key()
    
    for i, ip in enumerate(args.ips):
        idx = i + 1
        print(f"Processing Node {idx} ({ip})...")
        
        node_dir = os.path.join(DIST_DIR, f"node{idx}")
        secrets_dir = os.path.join(node_dir, "secrets")
        os.makedirs(secrets_dir, exist_ok=True)
        
        node_key_bytes = generate_node_key()
        enode = derive_enode(node_key_bytes, ip, QUORUM_PORT)
        validator_addr = Account.from_key(node_key_bytes).address
        
        device_root = generate_device_root_key()
        
        root_key_path = os.path.join(secrets_dir, "device_root.key")
        with open(root_key_path, "wb") as f:
            f.write(device_root)
            
        try:
            dkm = DeviceKeyManager(root_key_path)
            wallet_seed = dkm.get_wallet_seed()
            kiosk_account = Account.from_key(wallet_seed)
            kiosk_addr = kiosk_account.address
        except Exception as e:
            print(f"Failed to derive kiosk wallet: {e}")
            exit(1)
        
        print(f" Validator: {validator_addr}")
        print(f" Kiosk App: {kiosk_addr}")

        node_configs.append({
            "id": idx,
            "ip": ip,
            "key_bytes": node_key_bytes,
            "enode": enode,
            "validator_addr": validator_addr,
            "kiosk_addr": kiosk_addr,
            "node_dir": node_dir
        })
        
        kiosk_identities[idx] = {
            "ip": ip,
            "kiosk_address": kiosk_addr,
            "validator_address": validator_addr
        }
        node_entries.append(enode)

    val_addrs = [c['validator_addr'] for c in node_configs]
    kiosk_addrs = [c['kiosk_addr'] for c in node_configs]
    update_genesis(val_addrs, kiosk_addrs)

    for config in node_configs:
        node_dir = config['node_dir']
        
        config_dir = os.path.join(node_dir, "config")
        os.makedirs(config_dir, exist_ok=True)

        with open(os.path.join(config_dir, "static-nodes.json"), "w") as f:
            json.dump(node_entries, f, indent=4)
        
        with open(os.path.join(config_dir, "nodekey"), "w") as f:
            f.write(config['key_bytes'].hex())
            
        with open(os.path.join(config_dir, "swarm.key"), "w") as f:
            f.write(swarm_key)
            
        with open(os.path.join(config_dir, "nginx.conf"), "w") as f:
            f.write(create_nginx_conf(config['id']))

        print(f" Config for Node {config['id']} written to {node_dir}")

    client_dir = os.path.join(DIST_DIR, "client")
    os.makedirs(client_dir, exist_ok=True)
    rpc_nodes = [f"http://{ip}:8545" for ip in args.ips]
    ipfs_nodes = [f"/ip4/{ip}/tcp/5001" for ip in args.ips]
    client_config = {
        "network": {
            "chain_id": 1337,
            "rpc_nodes": rpc_nodes, 
            "ipfs_nodes": ipfs_nodes,
            "rpc_url": rpc_nodes[0],
            "ipfs_api": ipfs_nodes[0]
        }
    }
    import yaml
    with open(os.path.join(client_dir, "master.yaml"), "w") as f:
        yaml.dump(client_config, f)
        
    with open(KIOSK_ID_FILE, "w") as f:
        json.dump(kiosk_identities, f, indent=4)
    print(f" Kiosk Identities Exported to {KIOSK_ID_FILE}")

    print("\n[NEXT STEPS]")
    print(f"1. Run 'python provision/distribute_configs.py' to push keys.")
    print(f"2. Run 'python provision/cluster_manager.py provision' to set up nodes.")

if __name__ == "__main__":
    main()
