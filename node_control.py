                      
"""
NODE_CONTROL.py - Unified Node Management

Usage:
    python provision/NODE_CONTROL.py start --node-id 1
    python provision/NODE_CONTROL.py stop
    python provision/NODE_CONTROL.py restart --node-id 1
    python provision/NODE_CONTROL.py status
    python provision/NODE_CONTROL.py clean (WARNING: Wipes data)
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

def run_cmd(cmd, check=True, capture=False, timeout=None):
    """Helper to run shell commands."""
    try:
        result = subprocess.run(
            cmd, 
            check=check, 
            capture_output=capture, 
            text=True if capture else False,
            timeout=timeout
        )
        return result
    except subprocess.CalledProcessError as e:
        if check:
            print(f" Command failed: {' '.join(cmd)}\nError: {e.stderr if capture else e}")
            sys.exit(1)
        raise e

def stop_node(timeout=60):
    """Gracefully stops containers without deleting volumes."""
    print(" Stopping nodes (graceful shutdown)...")
    if not COMPOSE_FILE.exists():
        print(" No compose file found. Assuming already stopped.")
        return

    try:
                                                                       
        run_cmd(["docker", "compose", "-f", str(COMPOSE_FILE), "stop", "--timeout", str(timeout)])
        print(" Nodes stopped. Data preserved.")
    except Exception as e:
        print(f" Warning during stop: {e}")

def clean_locks():
    """Surgically removes lock files from volumes to prevent restart loops."""
    print(" Checking for stale lock files...")
    
    vol_quorum = "node_quorum_data"
    vol_ipfs = "node_ipfs_data"
    
    quorum_cmd = "rm -f /data/geth/LOCK /data/geth/chaindata/LOCK /data/geth.ipc 2>/dev/null; echo done"
    quorum_result = subprocess.run([
        "docker", "run", "--rm",
        "-v", f"{vol_quorum}:/data",
        "alpine", "sh", "-c", quorum_cmd
    ], capture_output=True, text=True)
    
    if quorum_result.returncode == 0:
        print(" Quorum locks cleared (chain data preserved)")
    else:
        print(f" Quorum lock cleanup skipped (volume may not exist): {quorum_result.stderr.strip()}")
    
    ipfs_cmd = "rm -f /data/ipfs/repo.lock /data/ipfs/datastore/LOCK 2>/dev/null; echo done"
    ipfs_result = subprocess.run([
        "docker", "run", "--rm",
        "-v", f"{vol_ipfs}:/data/ipfs",
        "alpine", "sh", "-c", ipfs_cmd
    ], capture_output=True, text=True)
    
    if ipfs_result.returncode == 0:
        print(" IPFS locks cleared (repo data preserved)")
    else:
        print(f" IPFS lock cleanup skipped (volume may not exist): {ipfs_result.stderr.strip()}")

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
    
    NODE_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CERTS_DIR.mkdir(parents=True, exist_ok=True)

    required = ["nodekey", "static-nodes.json", "swarm.key"]
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
    
    host_ip = detect_host_ip()
    print(f" Starting Node {node_id} on {host_ip}...")

    try:
        with open(NODE_CONFIG_DIR / "nodekey", "r") as f: 
            key_hex = f.read().strip()
        with open(NODE_CONFIG_DIR / "static-nodes.json", "rb") as f: 
            static_b64 = base64.b64encode(f.read()).decode()
        with open(NODE_CONFIG_DIR / "swarm.key", "rb") as f: 
            swarm_b64 = base64.b64encode(f.read()).decode()
    except Exception as e:
        print(f" Secret error: {e}")
        sys.exit(1)

    env = os.environ.copy()
    env.update({
        "HOST_IP": host_ip,
        "NODE_KEY_HEX": key_hex,
        "STATIC_NODES_B64": static_b64,
        "SWARM_KEY_B64": swarm_b64
    })

    result = subprocess.run(
        ["docker", "compose", "-f", str(COMPOSE_FILE), "up", "-d"],
        env=env,
        capture_output=True,
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

def wipe_data(force=False):
    """Destructive wipe of all volumes."""
    print("\n WARNING: This will DELETE all blockchain and IPFS data!")
    print(" This action cannot be undone.\n")
    
    if force:
        print(" (Force flag detected, skipping confirmation)")
        confirm = "yes"
    else:
        try:
            confirm = input("Type 'yes' to confirm: ")
        except EOFError:
            print(" Input not available. Use --force for non-interactive clean.")
            return

    if confirm.lower() == "yes":
        run_cmd(["docker", "compose", "-f", str(COMPOSE_FILE), "down", "-v"], check=False)
        print(" All data wiped. Run 'start' to create fresh volumes.")
    else:
        print(" Action cancelled.")

def main():
    parser = argparse.ArgumentParser(
        description="PRISM Node Control",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python provision/NODE_CONTROL.py start --node-id 1 # Start node
  python provision/NODE_CONTROL.py stop # Stop gracefully
  python provision/NODE_CONTROL.py restart --node-id 1 # Restart
  python provision/NODE_CONTROL.py status # Check health
  python provision/NODE_CONTROL.py clean # Wipe data (destructive)
        """
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    p_start = subparsers.add_parser("start", help="Start the node (preserves data)")
    p_start.add_argument("--node-id", type=int, required=True, help="Node ID (1-4)")
    p_start.add_argument("--no-wait", action="store_true", help="Skip peer discovery wait")

    p_stop = subparsers.add_parser("stop", help="Stop the node (graceful, preserves data)")
    p_stop.add_argument("--timeout", type=int, default=60, help="Shutdown timeout in seconds")

    p_restart = subparsers.add_parser("restart", help="Stop then start")
    p_restart.add_argument("--node-id", type=int, required=True, help="Node ID (1-4)")
    p_restart.add_argument("--no-wait", action="store_true", help="Skip peer discovery wait")

    subparsers.add_parser("status", help="Show node health and stats")

    p_clean = subparsers.add_parser("clean", help="Wipe all data (DESTRUCTIVE)")
    p_clean.add_argument("--force", action="store_true", help="Skip confirmation prompt")

    args = parser.parse_args()

    if args.command == "start":
        start_node(args.node_id, wait=not args.no_wait)
    elif args.command == "stop":
        stop_node(timeout=args.timeout)
    elif args.command == "restart":
        stop_node()
        time.sleep(2)
        start_node(args.node_id, wait=not args.no_wait)
    elif args.command == "status":
        check_status()
    elif args.command == "clean":
        wipe_data(force=args.force)

if __name__ == "__main__":
    main()
