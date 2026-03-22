#!/usr/bin/env python3
"""
setup_node.py - Single-Node Automated Setup

Run this on each Mini PC after setup_cluster.py has generated configs.

Usage:
    python provision/setup_node.py --node-id 1
"""

import argparse
import os
import shutil
import subprocess
import time
import json
import sys
import base64
from pathlib import Path


BASE_DEPLOY_DIR = Path("provision/deployment/node")
CONFIG_SOURCE_DIR = BASE_DEPLOY_DIR / "config"
COMPOSE_FILE = BASE_DEPLOY_DIR / "docker-compose.node.yaml"
GENESIS_SOURCE = Path("blockchain/genesis.json")
NODE_CONFIG_DIR = BASE_DEPLOY_DIR / "config"
CERTS_DIR = BASE_DEPLOY_DIR / "secrets/certs"

def check_config_exists(node_id: int) -> bool:
    """Verify required config files are present in the transfer source."""
    required = ["nodekey", "static-nodes.json", "swarm.key"]
    for f in required:
        src = CONFIG_SOURCE_DIR / f
        dest = NODE_CONFIG_DIR / f
        
        if not src.exists():
            if dest.exists() and dest.is_file():
                 print(f" ℹ Found existing config at {dest}")
                 continue
            
            print(f" Missing config: {f}")
            print(f" Checked source: {src}")
            print(f" Checked dest: {dest}")
            print(f" Please ensure distribute_configs.py was successful OR files are manually placed.")
            return False
    return True

def install_config(clean: bool = False):
    """Copy config files to the correct deployment directory for Docker Compose."""
    print(" Installing configuration files...")
    if clean:
        print(" Cleaning up volumes (--clean detected)...")
        try:
            subprocess.run(["docker", "compose", "-f", str(COMPOSE_FILE), "down", "-v"], capture_output=True)
        except:
            print(" Warning: Failed to prune volumes. Containers might already be down.")
    else:
        try:
            subprocess.run(["docker", "compose", "-f", str(COMPOSE_FILE), "down"], capture_output=True)
        except:
            pass

    BASE_DEPLOY_DIR.mkdir(parents=True, exist_ok=True)
    NODE_CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    if CONFIG_SOURCE_DIR.resolve() == NODE_CONFIG_DIR.resolve():
        print(" Config source and destination are the same. Skipping copy.")
        files_to_copy = []
    else:
        files_to_copy = ["nodekey", "static-nodes.json", "swarm.key", "nginx.conf"]

    if CERTS_DIR.exists() and CERTS_DIR.is_file():
        CERTS_DIR.unlink()
    CERTS_DIR.mkdir(parents=True, exist_ok=True)
    
    for f in files_to_copy:
        src = CONFIG_SOURCE_DIR / f
        dest = NODE_CONFIG_DIR / f

        if dest.exists() and dest.is_dir():
            print(f" Removing invalid directory {dest}...")
            try:
                shutil.rmtree(dest)
            except PermissionError:
                print(f" Permission Denied on {dest}")
                print(f" FIX: Run 'sudo rm -rf {dest}' on the node HOST.")
                sys.exit(1)

        if src.exists():
            try:
                if dest.exists():
                    dest.unlink()

                shutil.copy(src, dest)
                print(f" {f} → {dest}")
            except PermissionError:
                print(f" Permission Denied on {dest}")
                print(f" FIX: Run 'sudo chown -R $USER:$USER ~/Capstone && sudo rm -rf {dest}'")
                sys.exit(1)
            except Exception as e:
                print(f" Error copying {f}: {e}")
                sys.exit(1)
        else:
            if dest.exists() and dest.is_file():
                 print(f" Using existing {f} (no new source found)")
            else:
                 print(f" Warning: {f} missing in source AND dest. Docker will create a dir if you run!")

    cert_file = CERTS_DIR / "self-signed.crt"
    key_file = CERTS_DIR / "self-signed.key"
    try:
        if not cert_file.exists():
            cert_file.touch()
        if not key_file.exists():
            key_file.touch()
    except PermissionError:
        print(f" Permission Denied on {CERTS_DIR}")
        print(f" FIX: Run 'sudo chown -R $USER:$USER {BASE_DEPLOY_DIR}'")
        sys.exit(1)

def detect_host_ip():
    """Detect the most likely LAN IP, skipping Docker bridges."""
    try:
        ips = subprocess.check_output("hostname -I", shell=True).decode().strip().split()
        for ip in ips:
            if ip.startswith("192.168.") or ip.startswith("10."):
                return ip
            if ip.startswith("172."):
                second_octet = int(ip.split('.')[1])
                if second_octet > 19:
                    return ip
        
        if ips: return ips[0]
        
        import socket
        return socket.gethostbyname(socket.gethostname())
    except:
        return "127.0.0.1"

def start_docker(node_id: int):
    """Start Docker containers with host IP detection."""
    print("\n Starting Docker containers...")
    host_ip = detect_host_ip()
    print(f" Detected Host IP: {host_ip}")
    
    genesis_dest = BASE_DEPLOY_DIR / "genesis.json"
    if GENESIS_SOURCE.exists():
        try:
            if genesis_dest.exists():
                if genesis_dest.is_dir():
                    shutil.rmtree(genesis_dest)
                else:
                    genesis_dest.unlink()
            shutil.copy(GENESIS_SOURCE, genesis_dest)
            print(f" Genesis → {genesis_dest}")
        except PermissionError:
             print(f" Permission Denied on {genesis_dest}")
             sys.exit(1)
    
    print(" Cleaning up old containers...")
    subprocess.run(["docker", "rm", "-f", "quorum-node", "ipfs-node", "validator-proxy"], capture_output=True)
    
    print(" Removing stale lock files from volumes...")
    quorum_cleanup = subprocess.run([
        "docker", "run", "--rm",
        "-v", "prism_quorum-data:/qdata",
        "alpine", "sh", "-c",
        "rm -f /qdata/dd/LOCK /qdata/dd/geth/LOCK /qdata/dd/geth.ipc 2>/dev/null; echo done"
    ], capture_output=True, text=True)
    if quorum_cleanup.returncode == 0:
        print(" Quorum locks cleared (chain data preserved)")
    else:
        print(f" Quorum lock cleanup skipped: {quorum_cleanup.stderr.strip()}")
    
    ipfs_cleanup = subprocess.run([
        "docker", "run", "--rm",
        "-v", "prism_ipfs-data:/data/ipfs",
        "alpine", "sh", "-c",
        "rm -f /data/ipfs/repo.lock /data/ipfs/datastore/LOCK 2>/dev/null; echo done"
    ], capture_output=True, text=True)
    if ipfs_cleanup.returncode == 0:
        print(" IPFS locks cleared (repo data preserved)")
    else:
        print(f" IPFS lock cleanup skipped: {ipfs_cleanup.stderr.strip()}")
    
    print(" Encoding secrets for injection...")
    try:
        with open(NODE_CONFIG_DIR / "nodekey", "r", encoding="utf-8") as f:
            node_key_hex = f.read().strip()
            
        with open(NODE_CONFIG_DIR / "static-nodes.json", "rb") as f:
            static_nodes_b64 = base64.b64encode(f.read()).decode()
            
        with open(NODE_CONFIG_DIR / "swarm.key", "rb") as f:
            swarm_key_b64 = base64.b64encode(f.read()).decode()
            
    except Exception as e:
        print(f" Failed to read or encode secrets: {e}")
        sys.exit(1)

    env = os.environ.copy()
    env["HOST_IP"] = host_ip
    env["NODE_KEY_HEX"] = node_key_hex
    print(f" DEBUG: Injecting NODE_KEY_HEX={node_key_hex[:10]}...")
    env["STATIC_NODES_B64"] = static_nodes_b64
    env["SWARM_KEY_B64"] = swarm_key_b64
    
    result = subprocess.run(
        ["docker", "compose", "-f", str(COMPOSE_FILE), "up", "-d", "--force-recreate"],
        text=True,
        env=env
    )
    if result.returncode != 0:
        print(f" Docker failed: {result.stderr}")
        sys.exit(1)
    print(" Containers started")

    print("\n Validating Enode configuration...")
    try:
        enode_res = subprocess.run(
            ["docker", "exec", "quorum-node", "geth", "attach", "http://localhost:8545", "--exec", "admin.nodeInfo.enode"],
            capture_output=True, text=True
        )
        if enode_res.returncode == 0:
            local_enode = enode_res.stdout.strip().strip('"')
            with open(NODE_CONFIG_DIR / "static-nodes.json", "r") as f:
                static_nodes = json.load(f)
            
            local_id = local_enode.split("@")[0].split("//")[1]
            static_ids = [s.split("@")[0].split("//")[1] for s in static_nodes]
            
            if local_id in static_ids:
                print(f" Enode ID is correctly registered in static-nodes.json")
            else:
                print(f" WARNING: Local Enode ID NOT found in static-nodes.json!")
                print(f" Enode ID: {local_id[:16]}...")
                print(f" This node will NOT be able to connect to peers.")
                print(f" FIX: Ensure you are using the correct 'nodekey' file.")
    except Exception as e:
        print(f" Could not validate Enode: {e}")

def wait_for_peers(expected_peers: int = 3, timeout: int = 120):
    """Wait for node to discover peers."""
    print(f"\n Waiting for peer discovery ({expected_peers} peers expected)...")
    
    container = "quorum-node"
    start_time = time.time()
    peer_count = 0
    while time.time() - start_time < timeout:
        try:
            result = subprocess.run(
                ["docker", "exec", container, "geth", "attach", "http://localhost:8545", "--exec", "admin.peers.length"],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                output = result.stdout.strip()
                if output:
                    peer_count = int(output)
                    print(f" Peers: {peer_count}/{expected_peers}")
                    if peer_count >= expected_peers:
                        print(" All peers connected!")
                        return True
        except Exception:
            pass # Geth might not be ready yet
        
        time.sleep(5)
    
    print(f" Timeout: Only found {peer_count} peers after {timeout}s")
    return False

def optimize_ipfs():
    """Apply IPFS profiles to reduce background noise."""
    print("\n Optimizing IPFS for high-throughput environment...")
    profiles = ["lowpower", "local-discovery"]
    for profile in profiles:
        try:
            result = subprocess.run(
                ["docker", "exec", "ipfs-node", "ipfs", "config", "profile", "apply", profile],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                print(f" Profile '{profile}' applied.")
            else:
                print(f" Could not apply profile '{profile}': {result.stderr.strip()}")
        except Exception as e:
            print(f" Error optimizing IPFS: {e}")

def get_sync_status():
    """Check blockchain sync status."""
    print("\n Checking sync status...")
    
    container = "quorum-node"
    try:
        result = subprocess.run(
            ["docker", "exec", container, "geth", "attach", "http://localhost:8545", "--exec", "eth.blockNumber"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            block = result.stdout.strip()
            print(f" Block Height: {block}")
            return int(block)
    except Exception:
        pass
    return 0

def install_autostart():
    """Installs XDG Autostart entry for the host browser UI."""
    print("\n Installing XDG Autostart (kiosk.desktop)...")
    autostart_dir = Path.home() / ".config/autostart"
    autostart_dir.mkdir(parents=True, exist_ok=True)
    desktop_path = autostart_dir / "kiosk.desktop"
    content = f"""[Desktop Entry]
Type=Application
Name=PRISM Kiosk
Exec={Path.home()}/Capstone/provision/launch_kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
"""
    with open(desktop_path, "w") as f:
        f.write(content)
    
    script_path = Path.home() / "Capstone/provision/launch_kiosk.sh"
    subprocess.run(["chmod", "+x", str(script_path)], check=False)
    
    print(" Autostart entry installed")

def main():
    parser = argparse.ArgumentParser(description="Setup a single PRISM validator node")
    parser.add_argument("--node-id", type=int, required=True, help="Node ID (1-4)")
    parser.add_argument("--skip-docker", action="store_true", help="Skip Docker startup")
    parser.add_argument("--clean", action="store_true", help="Wipe Docker volumes before starting")
    parser.add_argument("--no-wait", action="store_true", help="Don't wait for peer discovery")
    parser.add_argument("--peers", type=int, default=3, help="Expected peer count")
    args = parser.parse_args()
    
    print(f"\n{'='*50}")
    print(f" PRISM Node Setup - Node {args.node_id}")
    print(f"{'='*50}\n")
    
    if not check_config_exists(args.node_id):
        sys.exit(1)
    print(" Configuration files found\n")
    
    install_config(clean=args.clean)
    
    if not args.skip_docker:
        start_docker(args.node_id)
        
        time.sleep(5)
        optimize_ipfs()
        
        install_autostart()
        
        if not args.no_wait:
            wait_for_peers(expected_peers=args.peers)
            get_sync_status()
        else:
            print("\n Skipping peer discovery wait (async mode)")
    
    print(f"\n{'='*50}")
    print(f" Node {args.node_id} Setup Logic Triggered!")
    print(f"{'='*50}")
    print("\nNext steps:")
    print(" 1. Run setup_node.py on other Mini PCs (if not automated)")
    print(" 2. Once all nodes are up and synced, run: python deploy.py")

if __name__ == "__main__":
    main()
