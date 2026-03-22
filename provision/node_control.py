#!/usr/bin/env python3
"""
node_control.py - Unified Node Management

Usage:
    python provision/node_control.py start --node-id 1
    python provision/node_control.py stop
    python provision/node_control.py restart --node-id 1
    python provision/node_control.py status
    python provision/node_control.py clean (WARNING: Wipes data)
"""

import argparse
import subprocess
import sys
import shutil
import time
import os
import base64
import json
from pathlib import Path

BASE_DEPLOY_DIR = Path("provision/deployment/node")
CONFIG_SOURCE_DIR = BASE_DEPLOY_DIR / "config"
NODE_CONFIG_DIR = BASE_DEPLOY_DIR / "config"
COMPOSE_FILE = BASE_DEPLOY_DIR / "docker-compose.node.yaml"
GENESIS_SOURCE = Path("blockchain/genesis.json")
CERTS_DIR = BASE_DEPLOY_DIR / "secrets/certs"

def run_cmd(cmd, check=True, capture=False, env=None, timeout=None):
    """Helper to run shell commands."""
    try:
        target_env = env if env is not None else os.environ.copy()
        result = subprocess.run(
            cmd, 
            check=check, 
            capture_output=capture, 
            text=True if capture else False,
            env=target_env,
            timeout=timeout
        )
        return result
    except subprocess.CalledProcessError as e:
        if check:
            print(f" Command failed: {' '.join(cmd)}\nError: {e.stderr if capture else e}")
            sys.exit(1)
        raise e



def manage_service(action):
    """Manages the systemd persistent UI service."""
    service_name = "kiosk-ui.service"
    
    check_res = subprocess.run(["systemctl", "--user", "list-unit-files", service_name], capture_output=True, text=True)
    if service_name not in check_res.stdout:
        return

    print(f" {action.capitalize()}ing {service_name}...")
    try:
        subprocess.run(["systemctl", "--user", action, service_name], check=False, capture_output=True)
    except Exception as e:
        print(f" Service control failed: {e}")

def stop_node(node_id=None, timeout=60):
    """Gracefully stops containers without deleting volumes."""
    print(" Stopping nodes (graceful shutdown)...")
    
    manage_service("stop")
    
    if not COMPOSE_FILE.exists():
        print(" No compose file found. Assuming already stopped.")
        return

    env = get_env(node_id) if node_id else os.environ.copy()

    try:
        run_cmd(["docker", "compose", "-f", str(COMPOSE_FILE), "down", "--timeout", str(timeout)], env=env)
        print(" Nodes stopped. Data preserved.")
    except Exception as e:
        print(f" Warning during stop: {e}")



def clean_locks():
    """Cleans up Geth/IPFS lock files that prevent startup."""
    print(" Cleaning stale lock files...")
    
    subprocess.run([
        "docker", "run", "--rm", 
        "-v", "node_quorum-data:/qdata", 
        "alpine", "rm", "-f", "/qdata/dd/geth/LOCK", "/qdata/dd/geth.ipc"
    ], capture_output=True)
    
    subprocess.run([
        "docker", "run", "--rm", 
        "-v", "node_ipfs-data:/data/ipfs", 
        "alpine", "rm", "-f", "/data/ipfs/repo.lock"
    ], capture_output=True)

def get_env(node_id):
    """Loads environment variables for Docker Compose."""
    host_ip = detect_host_ip()
    
    try:
        with open(NODE_CONFIG_DIR / "nodekey", "r") as f: 
            key_hex = f.read().strip()
        with open(NODE_CONFIG_DIR / "static-nodes.json", "rb") as f: 
            static_b64 = base64.b64encode(f.read()).decode()
        with open(NODE_CONFIG_DIR / "swarm.key", "rb") as f: 
            swarm_b64 = base64.b64encode(f.read()).decode()
    except Exception as e:
        print(f" Could not load all secrets for env: {e}")
        return os.environ.copy()

    env = os.environ.copy()
    env.update({
        "HOST_IP": host_ip,
        "NODE_KEY_HEX": key_hex,
        "STATIC_NODES_B64": static_b64,
        "SWARM_KEY_B64": swarm_b64
    })
    return env

def detect_host_ip():
    """Detect LAN IP, skipping Docker bridges."""
    try:
        ips = subprocess.check_output("hostname -I", shell=True).decode().strip().split()
        for ip in ips:
            if ip.startswith(("192.168.", "10.")): 
                return ip
            if ip.startswith("172.") and int(ip.split('.')[1]) > 19: 
                return ip
        return ips[0] if ips else "127.0.0.1"
    except:
        return "127.0.0.1"

def install_config(node_id):
    """Installs config files for Docker Compose."""
    print(" Verifying configuration...")
    
    # Check for Device Root Key (Centralized Provisioning Check)
    device_key_path = Path.home() / "Capstone/storage/keys/device_root.key"
    if not device_key_path.exists():
        print(f" CRITICAL: {device_key_path} NOT FOUND.")
        print(" Host has not been provisioned correctly.")
        print(" Run 'cluster_manager.py provision' from Admin PC first.")
        sys.exit(1)
        
    # Ensure directories
    NODE_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CERTS_DIR.mkdir(parents=True, exist_ok=True)

    # Copy config files if source != dest
    required = ["nodekey", "static-nodes.json", "swarm.key"]
# ...
    if CONFIG_SOURCE_DIR.resolve() != NODE_CONFIG_DIR.resolve():
        for f in required + ["nginx.conf"]:
            src = CONFIG_SOURCE_DIR / f
            dest = NODE_CONFIG_DIR / f
            if src.exists():
                if dest.exists() and dest.is_dir(): 
                    shutil.rmtree(dest)
                shutil.copy(src, dest)
                print(f" {f} installed")
            elif not dest.exists():
                print(f" Missing config: {f}")
                sys.exit(1)
    else:
        print(" ℹ Config source == dest, skipping copy")
    
    genesis_dest = BASE_DEPLOY_DIR / "genesis.json"
    if GENESIS_SOURCE.exists():
        if genesis_dest.exists() and genesis_dest.is_dir():
            shutil.rmtree(genesis_dest)
        shutil.copy(GENESIS_SOURCE, genesis_dest)
        print(" genesis.json installed")


    (CERTS_DIR / "self-signed.crt").touch()
    (CERTS_DIR / "self-signed.key").touch()

def start_node(node_id, wait=True):
    """Starts the node stack with lock cleanup."""
    install_config(node_id)
    clean_locks()
    env = get_env(node_id)
    print(f" Starting Node {node_id} on {env.get('HOST_IP', 'unknown')}...")

    result = subprocess.run(
        ["docker", "compose", "-f", str(COMPOSE_FILE), "up", "-d", "--force-recreate"],
        env=env,
        text=True
    )
    if result.returncode != 0:
        print(f" Docker failed: {result.stderr}")
        sys.exit(1)
    print(" Containers started")
    
    time.sleep(5)
    print(" Applying IPFS profiles...")
    subprocess.run(
        ["docker", "exec", "ipfs-node", "ipfs", "config", "profile", "apply", "lowpower"], 
        capture_output=True
    )
    subprocess.run(
        ["docker", "exec", "ipfs-node", "ipfs", "config", "profile", "apply", "local-discovery"], 
        capture_output=True
    )

    if wait:
        wait_for_peers()
    else:
        print(" Skipping peer wait (--no-wait)")
        
    manage_service("start")

def wait_for_peers(expected=3, timeout=120):
    """Wait for peer discovery."""
    print(f" Waiting for peers ({expected} expected)...")
    start = time.time()
    while time.time() - start < timeout:
        try:
            res = subprocess.run(
                ["docker", "exec", "quorum-node", "geth", "attach", 
                 "http://localhost:8545", "--exec", "admin.peers.length"],
                capture_output=True, text=True
            )
            if res.returncode == 0:
                count = int(res.stdout.strip())
                print(f" Peers: {count}/{expected}")
                if count >= expected:
                    print(" All peers connected!")
                    return True
        except: 
            pass
        time.sleep(5)
    
    print(f" Timeout: not all peers found (node is running, just lonely)")
    return False

def check_status():
    """Prints node status."""
    print("\n Node Status:")
    print("-" * 40)
    
    subprocess.run(["docker", "compose", "-f", str(COMPOSE_FILE), "ps"])
    
    try:
        res = subprocess.run(
            ["docker", "exec", "quorum-node", "geth", "attach", 
             "http://localhost:8545", "--exec", "eth.blockNumber"],
            capture_output=True, text=True
        )
        if res.returncode == 0:
            print(f"\n Block Height: {int(res.stdout.strip())}")
        else:
            print("\n Block Height: Unreachable")
    except:
        print("\n Block Height: Unreachable (Container down?)")
    
    try:
        res = subprocess.run(
            ["docker", "exec", "quorum-node", "geth", "attach", 
             "http://localhost:8545", "--exec", "admin.peers.length"],
            capture_output=True, text=True
        )
        if res.returncode == 0:
            print(f" Peers: {int(res.stdout.strip())}")
    except:
        pass

def wipe_data(args):
    """Wipes all persistent data."""
    print("\n Cleaning Node Data...")
    
    if not args.force:
        print("\n WARNING: This will DELETE ALL NODE DATA (blockchain, IPFS, etc.).")
        print(" This action is irreversible.")
        confirm = input(" Type 'yes' to proceed: ")
        if confirm != "yes":
            print(" Aborted.")
            return

    stop_node(timeout=10)
    
    index_db = Path.home() / "Capstone/storage/index.db"
    if index_db.exists():
        try:
            index_db.unlink()
            print(" Removed index.db")
        except Exception as e:
            print(f" Failed to remove index.db: {e}")

    run_cmd(["docker", "compose", "-f", str(COMPOSE_FILE), "down", "-v", "--remove-orphans"], check=False)
    
    print(" Removing persistent volumes...")
    volumes = ["node_quorum-data", "node_ipfs-data"]
    for vol in volumes:
        run_cmd(["docker", "volume", "rm", "-f", vol], check=False)
        
    print(" All data wiped. Run 'start' to create fresh volumes.")



def main():
    parser = argparse.ArgumentParser(
        description="PRISM Node Control",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python provision/node_control.py start --node-id 1
  python provision/node_control.py stop
  python provision/node_control.py restart --node-id 1
  python provision/node_control.py status
  python provision/node_control.py clean
        """
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Start
    p_start = subparsers.add_parser("start", help="Start the node (preserves data)")
    p_start.add_argument("--node-id", type=int, required=True, help="Node ID (1-4)")
    p_start.add_argument("--no-wait", action="store_true", help="Skip peer discovery wait")

    # Stop
    p_stop = subparsers.add_parser("stop", help="Stop the node (graceful, preserves data)")
    p_stop.add_argument("--timeout", type=int, default=60, help="Shutdown timeout in seconds")

    # Restart
    p_restart = subparsers.add_parser("restart", help="Stop then start")
    p_restart.add_argument("--node-id", type=int, required=True, help="Node ID (1-4)")
    p_restart.add_argument("--no-wait", action="store_true", help="Skip peer discovery wait")

    # Status
    subparsers.add_parser("status", help="Show node health and stats")

    # Clean
    clean_parser = subparsers.add_parser("clean", help="Wipe all data (DESTRUCTIVE)")
    clean_parser.add_argument("--force", action="store_true", help="Skip confirmation")

    args = parser.parse_args()

    if args.command == "start":
        start_node(args.node_id, wait=not args.no_wait)
    elif args.command == "stop":
        stop_node(timeout=args.timeout)
    elif args.command == "restart":
        stop_node(node_id=args.node_id)
        time.sleep(2)
        start_node(args.node_id, wait=not args.no_wait)
    elif args.command == "status":
        check_status()
    elif args.command == "clean":
        wipe_data(args)

if __name__ == "__main__":
    main()
