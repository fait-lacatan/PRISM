#!/usr/bin/env python3
"""
remote_setup.py - Automate setup_node.py on all nodes via SSH

Run this on the Admin PC after distribute_configs.py to finalize node setup.
"""

import subprocess
import sys
import yaml
from pathlib import Path

# --- Configuration ---
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
NETWORK_CONFIG = PROJECT_ROOT / "provision" / "network_config.yaml"

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

def run_remote_setup(node_id: int, host: str) -> bool:
    """Run SETUP_NODE.py on a single node via SSH."""
    print(f" Initializing Setup on Node {node_id} ({host})...")
    
    remote_cmd = f"cd ~/Capstone && python3 -u provision/setup_node.py --node-id {node_id} --no-wait"
    
    ssh_cmd = ["ssh", host, remote_cmd]
    
    try:
        process = subprocess.Popen(ssh_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        
        for line in process.stdout:
            print(f" [{node_id}] {line.strip()}")
            
        process.wait()
        
        if process.returncode != 0:
            print(f" Node {node_id} setup failed with return code {process.returncode}")
            return False
        
        return True
    except Exception as e:
        print(f" SSH Error on Node {node_id}: {e}")
        return False

def main():
    print("\n" + "="*50)
    print(" PRISM Remote Node Setup Automation")
    print("="*50 + "\n")
    
    nodes = load_node_config()
    success = 0
    failed = 0
    
    for node_id, info in nodes.items():
        host = info if isinstance(info, str) else info.get("host", f"user@{info['ip']}")
        
        if run_remote_setup(node_id, host):
            print(f" Node {node_id} setup complete!\n")
            success += 1
        else:
            print(f" Node {node_id} setup encountered issues.\n")
            failed += 1
    
    print("="*50)
    print(f" Summary: {success} success, {failed} failed")
    print("="*50)
    
    if failed > 0:
        print("\n Some nodes failed setup. Please check the logs above.")
        sys.exit(1)
    
    print("\nNext steps:")
    print(" All nodes are ready. You can now run: python3 deploy.py")

if __name__ == "__main__":
    main()
