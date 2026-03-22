"""
distribute_configs.py - Automate Config Transfer to Nodes

Run this on the Admin PC after setup_cluster.py to SCP configs to all nodes.

Usage:
    python provision/distribute_configs.py
    
Prerequisites:
    - SSH keys configured for passwordless access
    - All nodes reachable on network
"""

import subprocess
import sys
import yaml
from pathlib import Path

# --- Configuration ---
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
DIST_DIR = PROJECT_ROOT / "provision" / "dist"
NETWORK_CONFIG = PROJECT_ROOT / "provision" / "network_config.yaml"
REMOTE_PATH = "~/Capstone/provision/deployment/node/config/"

DEFAULT_NODES = {
    1: {"host": "prism@192.168.8.101", "ip": "192.168.8.101"},
    2: {"host": "prism@192.168.8.102", "ip": "192.168.8.102"},
    3: {"host": "prism@192.168.8.103", "ip": "192.168.8.103"},
    4: {"host": "prism@192.168.8.104", "ip": "192.168.8.104"},
}

def load_node_config():
    """Load node configuration from YAML or use defaults."""
    if NETWORK_CONFIG.exists():
        with open(NETWORK_CONFIG) as f:
            config = yaml.safe_load(f)
            return config.get("nodes", DEFAULT_NODES)
    return DEFAULT_NODES

def distribute_config(node_id: int, host: str) -> bool:
    """SCP config folder to a single node."""
    src = DIST_DIR / f"node{node_id}"
    
    if not src.exists():
        print(f" Source not found: {src}")
        return False
    
    mkdir_cmd = ["ssh", host, f"mkdir -p {REMOTE_PATH}"]
    subprocess.run(mkdir_cmd, capture_output=True)

    remote_genesis_dir = "~/Capstone/blockchain/"
    subprocess.run(["ssh", host, f"mkdir -p {remote_genesis_dir}"], capture_output=True)
    
    remote_keys_dir = "~/Capstone/storage/keys/"
    subprocess.run(["ssh", host, f"mkdir -p {remote_keys_dir}"], capture_output=True)
    
    src_config = src / "config"
    scp_cmd = ["scp", "-r", f"{src_config}/.", f"{host}:{REMOTE_PATH}"]
    result = subprocess.run(scp_cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f" Config Transfer Failed: {result.stderr}")
        return False

    src_secrets = src / "secrets" / "device_root.key"
    if src_secrets.exists():
        scp_key = ["scp", str(src_secrets), f"{host}:{remote_keys_dir}"]
        res_key = subprocess.run(scp_key, capture_output=True, text=True)
        if res_key.returncode != 0:
             print(f" Key Transfer Failed: {res_key.stderr}")
             return False
        subprocess.run(["ssh", host, f"chmod 600 {remote_keys_dir}device_root.key"], capture_output=True)
        print(f" Device Root Key transferred and secured.")
    else:
        print(f" No device_root.key found in {src_secrets}. Kiosk may not start correctly.")

    local_genesis = PROJECT_ROOT / "blockchain" / "genesis.json"
    scp_genesis = ["scp", str(local_genesis), f"{host}:{remote_genesis_dir}genesis.json"]
    res_genesis = subprocess.run(scp_genesis, capture_output=True, text=True)

    if res_genesis.returncode != 0:
        print(f" Genesis Transfer Failed: {res_genesis.stderr}")
        return False
        
    local_compose = PROJECT_ROOT / "provision" / "deployment" / "node" / "docker-compose.node.yaml"
    remote_compose_dir = "~/Capstone/provision/deployment/node/"
    scp_compose = ["scp", str(local_compose), f"{host}:{remote_compose_dir}"]
    res_compose = subprocess.run(scp_compose, capture_output=True, text=True)

    if res_compose.returncode != 0:
        print(f" Compose File Transfer Failed: {res_compose.stderr}")
        return False
    
    return True

def main():
    print("\n" + "="*50)
    print(" PRISM Config Distribution")
    print("="*50 + "\n")
    
    # Check dist folder exists
    if not DIST_DIR.exists():
        print(" dist/ folder not found. Run setup_cluster.py first.")
        sys.exit(1)
    
    nodes = load_node_config()
    success = 0
    failed = 0
    
    for node_id, info in nodes.items():
        host = info if isinstance(info, str) else info.get("host", f"user@{info['ip']}")
        print(f" Node {node_id} ({host})...")
        
        if distribute_config(node_id, host):
            print(f" Config transferred\n")
            success += 1
        else:
            print(f" Transfer failed\n")
            failed += 1
    
    print("="*50)
    print(f" Results: {success} success, {failed} failed")
    print("="*50)
    
    if failed > 0:
        print("\n Some transfers failed. Check SSH connectivity.")
        sys.exit(1)
    
    print("\nNext steps:")
    print(" SSH into each node and run:")
    print(" python provision/setup_node.py --node-id X")

if __name__ == "__main__":
    main()
