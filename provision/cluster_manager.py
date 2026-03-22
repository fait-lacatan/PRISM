"""
cluster_manager.py - Unified Cluster Orchestration

Single entry point for all cluster operations.
Reads provision/network_config.yaml as the Single Source of Truth.
"""

import argparse
import subprocess
import yaml
import json
import os
import sys
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

WALLET_SEED_KEY = "storage/keys/wallet_seed.key"

SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
NETWORK_CONFIG_PATH = SCRIPT_DIR / "network_config.yaml"
SETUP_CLUSTER_SCRIPT = SCRIPT_DIR / "setup_cluster.py"
DISTRIBUTE_SCRIPT = SCRIPT_DIR / "distribute_configs.py"
REMOTE_SETUP_SCRIPT = SCRIPT_DIR / "remote_setup.py"
DEPLOY_SCRIPT = PROJECT_ROOT / "deploy.py"

def load_config():
    if not NETWORK_CONFIG_PATH.exists():
        print(f" Config not found: {NETWORK_CONFIG_PATH}")
        sys.exit(1)
    with open(NETWORK_CONFIG_PATH) as f:
        return yaml.safe_load(f)

def get_nodes(config):
    """Returns a list of node dicts {id, ip, host}."""
    nodes = []
    raw = config.get("nodes", {})
    for k, v in raw.items():
        node = {"id": k}
        if isinstance(v, str):
             node["ip"] = v.split("@")[1] if "@" in v else v
             node["host"] = v
        else:
             node["ip"] = v["ip"]
             node["host"] = v.get("host", f"prism@{v['ip']}")
        nodes.append(node)
    return nodes

def run_cmd(cmd, cwd=None, check=True):
    print(f"RUNNING: {' '.join(cmd)}")
    try:
        subprocess.run(cmd, cwd=cwd, check=check)
    except subprocess.CalledProcessError as e:
        print(f" Command failed: {e}")
        if check: sys.exit(1)

def run_ssh(host, cmd, check=True, capture=True):
    ssh_cmd = ["ssh", host, cmd]
    if capture:
        return subprocess.run(ssh_cmd, check=check, capture_output=True, text=True)
    else:
        return subprocess.run(ssh_cmd, check=check)



def cmd_setup(args, config):
    """Generates keys and configs."""
    print(" Generating Cluster Config...")
    nodes = get_nodes(config)
    ips = [n["ip"] for n in nodes]
    
    cmd = ["python3", str(SETUP_CLUSTER_SCRIPT), "--ips"] + ips
    run_cmd(cmd)

def cmd_distribute(args, config):
    """Distributes keys to nodes."""
    print("SCP Configs to Nodes...")
    run_cmd(["python3", str(DISTRIBUTE_SCRIPT)])

def cmd_provision(args, config):
    """Installs dependencies and sets up Docker on nodes."""
    print("Provisioning Nodes...")
    run_cmd(["python3", str(REMOTE_SETUP_SCRIPT)])

def cmd_sync_master(args, config):
    """Syncs master.yaml to all nodes."""
    print(" Syncing master.yaml to nodes...")
    nodes = get_nodes(config)
    local_master = PROJECT_ROOT / "blockchain" / "master.yaml"
    remote_master_dir = "~/Capstone/blockchain/"
    
    for node in nodes:
        host = node["host"]
        print(f"  -> {host}...", end=" ", flush=True)
        run_ssh(host, f"mkdir -p {remote_master_dir}", check=False)
        if subprocess.run(["scp", str(local_master), f"{host}:{remote_master_dir}master.yaml"]).returncode == 0:
            print("OK")
        else:
            print("FAIL")

def cmd_deploy(args, config):
    """Deploys contracts and authorizes nodes."""
    print(" Deploying Contracts...")
    run_cmd(["python3", str(DEPLOY_SCRIPT)], cwd=PROJECT_ROOT)
    cmd_sync_master(args, config)

def cmd_peer_ipfs(args, config):
    """Meshes IPFS nodes."""
    print(" Meshing IPFS Swarm...")
    nodes = get_nodes(config)
    peers = []
    
    print("Gathering Peer IDs...")
    for node in nodes:
        host = node["host"]
        res = run_ssh(host, "docker exec ipfs-node ipfs id -f='<id>'", check=False)
        if res.returncode == 0 and res.stdout.strip():
            pid = res.stdout.strip()
            peers.append({"id": pid, "ip": node["ip"], "host": host})
            print(f" - Node {node['id']}: {pid}")
        else:
            print(f" Node {node['id']} IPFS not reachable.")
            
    import shlex
    for node in peers:
        others = [
            {"ID": peer["id"], "Addrs": [f"/ip4/{peer['ip']}/tcp/4001"]}
            for peer in peers if peer["id"] != node["id"]
        ]
        json_arg = shlex.quote(json.dumps(others))
        
        print(f"  Applying mesh to {node['host']}...")
        run_ssh(node["host"], f"docker exec ipfs-node ipfs config Peering.Peers --json {json_arg}", check=False)
        run_ssh(node["host"], "docker restart ipfs-node", check=False)
        
    print(" IPFS Mesh Configured.")

def cmd_sync_scripts(args, config):
    """Syncs provision scripts to all nodes."""
    print(" Syncing provision scripts to nodes...")
    nodes = get_nodes(config)
    local_provision = PROJECT_ROOT / "provision"
    remote_provision_dir = "~/Capstone/"
    
    for node in nodes:
        host = node["host"]
        print(f" -> {host}...", end=" ", flush=True)
        scripts = ["node_control.py", "setup_cluster.py", "setup_node.py", "launch_kiosk.sh", "monitor.py"]
        run_ssh(host, f"mkdir -p ~/Capstone/provision/deployment/node", check=False)
        
        success = True
        for script in scripts:
            src = local_provision / script
            dst = f"{host}:~/Capstone/provision/{script}"
            if subprocess.run(["scp", str(src), dst], capture_output=True).returncode != 0:
                success = False
        
        deploy_src = local_provision / "deployment" / "node"
        deploy_dst = f"{host}:~/Capstone/provision/deployment/"
        if subprocess.run(["scp", "-r", str(deploy_src), deploy_dst], capture_output=True).returncode != 0:
            success = False
        
        if success:
            print("OK")
        else:
            print("FAIL")

def cmd_sync_app(args, config):
    """Syncs core application source files to all nodes."""
    print(" Syncing application source to nodes...")
    nodes = get_nodes(config)
    
    app_files = [
        "backend.py", "kiosk.py", "identity_agent.py", "indexer.py", 
        "requirements.txt", "instrumentation.py", "sensor.py", "attendance.py",
        "face/master.yaml", "finger/master.yaml", "reference/fplib/fpmain.py"
    ]
    
    for node in nodes:
        host = node["host"]
        print(f" -> {host}...", end=" ", flush=True)
        
        success = True
        for f in app_files:
            src = PROJECT_ROOT / f
            if not src.exists():
                continue
            dst = f"{host}:~/Capstone/{f}"
            if subprocess.run(["scp", str(src), dst], capture_output=True).returncode != 0:
                success = False
        
        if success:
            print("OK")
        else:
            print("FAIL")

def cmd_control(args, config, action):
    """Start/Stop/Restart nodes."""
    print(f" {action.capitalize()}ing Cluster...")
    nodes = get_nodes(config)
    
    for node in nodes:
        host = node["host"]
        print(f"  -> {host}...", end=" ", flush=True)
        remote_script = "~/Capstone/provision/node_control.py"
        cmd_str = f"python3 {remote_script} {action}"
        if action != "stop" and action != "clean":
             cmd_str += f" --node-id {node['id']}"
             if args.no_wait:
                 cmd_str += " --no-wait"
        if action == "clean":
            cmd_str += " --force"
        full_cmd = f"cd ~/Capstone && {cmd_str}"
        res = run_ssh(host, full_cmd, check=False, capture=False)
        if res.returncode == 0:
            print("OK")
        else:
            print(f"FAIL: Return Code {res.returncode}")

def cmd_provision_identities(args, config):
    """
    Ensures each node has a unique Ethereum identity (node_identity.key),
    grants canEnroll + canRecord on-chain, and updates master.yaml to use it.
    
    This fixes nonce collisions caused by all nodes sharing genesis_deployer.key.
    Run after 'deploy' whenever nodes are reset or re-provisioned.
    """
    try:
        from web3 import Web3
        from eth_account import Account
        from web3.middleware import ExtraDataToPOAMiddleware
    except ImportError:
        print(" web3/eth_account not installed. Run: pip install web3")
        sys.exit(1)


    master_yaml_path = PROJECT_ROOT / "blockchain" / "master.yaml"
    with open(master_yaml_path) as f:
        master_cfg = yaml.safe_load(f)

    rpc_url = master_cfg.get('network', {}).get('rpc_url', 'http://192.168.8.101:8545')
    chain_id = master_cfg.get('network', {}).get('chain_id', 1337)
    registry_addr = master_cfg.get('contracts', {}).get('registry', {}).get('address')
    registry_abi_path = PROJECT_ROOT / master_cfg.get('contracts', {}).get('registry', {}).get('abi_path', '')
    perm_addr = master_cfg.get('contracts', {}).get('permissions', {}).get('address')
    perm_abi_path = PROJECT_ROOT / master_cfg.get('contracts', {}).get('permissions', {}).get('abi_path', '')
    admin_key_path = PROJECT_ROOT / master_cfg.get('network', {}).get('admin_key_path', 'storage/keys/genesis_deployer.key')
    static_nodes_path = PROJECT_ROOT / "blockchain" / "static-nodes.json"

    if not registry_addr:
        print(" Registry address not found in master.yaml. Run 'deploy' first.")
        sys.exit(1)

    w3 = Web3(Web3.HTTPProvider(rpc_url))
    w3.middleware_onion.inject(ExtraDataToPOAMiddleware, layer=0)
    if not w3.is_connected():
        print(f" Cannot connect to blockchain at {rpc_url}")
        sys.exit(1)

    deployer = Account.from_key(open(admin_key_path).read().strip())
    registry_abi = json.load(open(registry_abi_path))['abi']
    registry = w3.eth.contract(address=registry_addr, abi=registry_abi)
    
    perm_contract = None
    if perm_addr and perm_abi_path.exists():
        perm_abi = json.load(open(perm_abi_path))['abi']
        perm_contract = w3.eth.contract(address=perm_addr, abi=perm_abi)

    nonce = w3.eth.get_transaction_count(deployer.address, 'latest')

    print(f" Provisioning unique identities for {len(get_nodes(config))} nodes...")
    print(f" Admin: {deployer.address}")
    print(f" Registry: {registry_addr}")

    static_enodes = []
    if static_nodes_path.exists():
        static_enodes = json.load(open(static_nodes_path))

    local_root_key = PROJECT_ROOT / "storage" / "keys" / "device_root.key"
    if local_root_key.exists():
        print(f"\n Syncing shared device_root.key to all nodes...")
        for node in get_nodes(config):
            host = node['host']
            res = subprocess.run(
                ["scp", str(local_root_key), f"{host}:~/Capstone/storage/keys/device_root.key"],
                capture_output=True
            )
            if res.returncode == 0:
                run_ssh(host, "chmod 600 ~/Capstone/storage/keys/device_root.key", check=False, capture=True)
                print(f" {host}: device_root.key synced")
            else:
                print(f" {host}: device_root.key sync FAILED — {res.stderr.decode().strip()}")
    else:
        print(f" No local device_root.key found at {local_root_key}. Skipping sync.")

    nodes = get_nodes(config)
    for node in nodes:
        host = node['host']
        node_id = node['id']
        remote_key = f"~/Capstone/{WALLET_SEED_KEY}"
        print(f"\n--- Node {node_id} ({node['ip']}) ---")

        node_ip = node['ip']
        try:
            from prism.keys import KeyDerivationManager as DeviceKeyManager
            dm = DeviceKeyManager(str(local_root_key))
            wallet_seed = dm.get_wallet_seed_for_node(node_ip)
            node_acc = Account.from_key(wallet_seed)
            wallet_hex = wallet_seed.hex()
        except Exception as e:
            print(f" Failed to derive wallet_seed for {node_ip}: {e}")
            continue

        write_script = (
            f"python3 -c \""
            f"import os; "
            f"p = os.path.expanduser('{remote_key}'); "
            f"os.makedirs(os.path.dirname(p), exist_ok=True); "
            f"open(p, 'w').write('{wallet_hex}'); "
            f"os.chmod(p, 0o600); "
            f"print('written')\""
        )
        res = run_ssh(host, write_script, check=False, capture=True)
        if res.returncode != 0 or 'written' not in res.stdout:
            print(f" Failed to write wallet_seed.key: {res.stderr.strip()}")
            continue

        node_addr = node_acc.address
        print(f" Address: {node_addr} [wallet_seed via HKDF(device_root, salt={node_ip})]")

        # Match enode from static-nodes.json
        enode_url = None
        for enode in static_enodes:
            if node_ip in enode:
                enode_url = enode
                break
        
        if not enode_url:
            print(f" Could not find enode for {node_ip} in static-nodes.json")

        if enode_url and perm_contract:
            try:
                tx_perm = perm_contract.functions.addNode(enode_url).build_transaction({
                    'from': deployer.address, 'nonce': nonce, 'gas': 300000, 'gasPrice': 0, 'chainId': chain_id
                })
                signed_perm = deployer.sign_transaction(tx_perm)
                tx_hash_perm = w3.eth.send_raw_transaction(signed_perm.raw_transaction)
                w3.eth.wait_for_transaction_receipt(tx_hash_perm)
                print(f" [+] Consensus Node Added")
                nonce += 1
            except Exception as e:
                if "Node already exists" in str(e) or "already exists" in str(e).lower():
                    print(f" [+] Consensus Node already exists")
                else:
                    print(f" Consensus Add failed: {e}")

            try:
                from eth_utils import keccak
                enode_hash = keccak(text=enode_url)
                

                current_map = registry.functions.kioskEnodes(node_addr).call()
                if current_map != enode_hash:
                    tx_reg = registry.functions.registerKioskEnode(node_addr, enode_hash).build_transaction({
                        'from': deployer.address, 'nonce': nonce, 'gas': 200000, 'gasPrice': 0, 'chainId': chain_id
                    })
                    signed_reg = deployer.sign_transaction(tx_reg)
                    tx_hash_reg = w3.eth.send_raw_transaction(signed_reg.raw_transaction)
                    w3.eth.wait_for_transaction_receipt(tx_hash_reg)
                    print(f" [+] Kiosk Wallet Mapped to Enode")
                    nonce += 1
                else:
                    print(f" [+] Kiosk Wallet already mapped")
            except Exception as e:
                print(f" Enode Mapping failed: {e}")


        try:
            if not registry.functions.canEnroll(node_addr).call():
                tx = registry.functions.setEnrollAuth(node_addr, True).build_transaction({
                    'from': deployer.address, 'nonce': nonce, 'gas': 100000, 'gasPrice': 0, 'chainId': chain_id
                })
                signed = deployer.sign_transaction(tx)
                tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=30)
                print(f" canEnroll granted (block {receipt.blockNumber})")
                nonce += 1
            else:
                print(f" canEnroll already set")
        except Exception as e:
            print(f" canEnroll failed: {e}")


        try:
            if not registry.functions.canRecord(node_addr).call():
                tx = registry.functions.setKioskRecordAuth(node_addr, True).build_transaction({
                    'from': deployer.address, 'nonce': nonce, 'gas': 100000, 'gasPrice': 0, 'chainId': chain_id
                })
                signed = deployer.sign_transaction(tx)
                tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=30)
                print(f" canRecord granted (block {receipt.blockNumber})")
                nonce += 1
            else:
                print(f" canRecord already set")
        except Exception as e:
            print(f" canRecord failed: {e}")


        update_script = (
            f"python3 -c \""
            f"import yaml; "
            f"p = os.path.expanduser('~/Capstone/blockchain/master.yaml'); "
            f"cfg = yaml.safe_load(open(p)) or {{}}; "
            f"cfg.setdefault('identities', {{}})['user_key_path'] = '{WALLET_SEED_KEY}'; "
            f"cfg.setdefault('network', {{}})['user_key_path'] = '{WALLET_SEED_KEY}'; "
            f"open(p, 'w').write(yaml.dump(cfg, default_flow_style=False)); "
            f"print('master.yaml updated')\""
        )
        res2 = run_ssh(host, f"python3 -c "
            f"\"import yaml, os; "
            f"p = os.path.expanduser('~/Capstone/blockchain/master.yaml'); "
            f"cfg = yaml.safe_load(open(p)) or {{}}; "
            f"cfg.setdefault('identities', {{}})['user_key_path'] = '{WALLET_SEED_KEY}'; "
            f"cfg.setdefault('network', {{}})['user_key_path'] = '{WALLET_SEED_KEY}'; "
            f"open(p, 'w').write(yaml.dump(cfg, default_flow_style=False)); "
            f"print('master.yaml updated')\"",
            check=False, capture=True)
        if res2.returncode == 0:
            print(f" master.yaml updated to use wallet_seed.key")
        else:
            print(f" master.yaml update failed: {res2.stderr.strip()}")

    print("\n Restarting validator-ai on all nodes to pick up new identity...")
    for node in nodes:
        run_ssh(node['host'], "docker restart validator-ai", check=False, capture=True)
        print(f" {node['host']} restarted")

    print("\n Identity provisioning complete.")
    print(" Each node now has a unique signing key with canEnroll + canRecord.")


def cmd_status(args, config):
    """Checks status of all nodes."""
    print(" Cluster Status")
    nodes = get_nodes(config)
    
    for node in nodes:
        print(f"\n--- Node {node['id']} ({node['ip']}) ---")
        host = node["host"]
        remote_script = "~/Capstone/provision/node_control.py"
        res = run_ssh(host, f"cd ~/Capstone && python3 {remote_script} status", check=False, capture=True)
        print(res.stdout)

def main():
    parser = argparse.ArgumentParser(description="PRISM Cluster Orchestrator")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    config = load_config()


    subparsers.add_parser("setup", help="Generate keys and configs")
    subparsers.add_parser("distribute", help="Push configs to nodes")
    subparsers.add_parser("provision", help="Install dependencies on nodes")
    subparsers.add_parser("deploy", help="Deploy contracts and authorize")
    subparsers.add_parser("provision-identities", help="Generate unique per-node keys, grant canEnroll+canRecord, update master.yaml")
    subparsers.add_parser("sync-master", help="Sync master.yaml to nodes")
    subparsers.add_parser("sync-scripts", help="Sync provision scripts to nodes")
    subparsers.add_parser("sync-app", help="Sync core application source files")
    subparsers.add_parser("peer-ipfs", help="Mesh IPFS swarm")
    

    p_start = subparsers.add_parser("start-all", help="Start all nodes")
    p_start.add_argument("--no-wait", action="store_true")
    
    p_stop = subparsers.add_parser("stop-all", help="Stop all nodes")
    
    p_restart = subparsers.add_parser("restart-all", help="Restart all nodes")
    p_restart.add_argument("--no-wait", action="store_true")

    subparsers.add_parser("clean-all", help="Wipe all data (Destructive)")
    subparsers.add_parser("reset-all", help="Alias for clean-all")
    subparsers.add_parser("status", help="Check status")

    args = parser.parse_args()

    if args.command == "setup": cmd_setup(args, config)
    elif args.command == "distribute": cmd_distribute(args, config)
    elif args.command == "provision": cmd_provision(args, config)
    elif args.command == "deploy": cmd_deploy(args, config)
    elif args.command == "provision-identities": cmd_provision_identities(args, config)
    elif args.command == "sync-master": cmd_sync_master(args, config)
    elif args.command == "sync-scripts": cmd_sync_scripts(args, config)
    elif args.command == "sync-app": cmd_sync_app(args, config)
    elif args.command == "peer-ipfs": cmd_peer_ipfs(args, config)
    elif args.command == "start-all": cmd_control(args, config, "start")
    elif args.command == "stop-all": cmd_control(args, config, "stop")
    elif args.command == "restart-all": cmd_control(args, config, "restart")
    elif args.command in ["clean-all", "reset-all"]: cmd_control(args, config, "clean")
    elif args.command == "status": cmd_status(args, config)

if __name__ == "__main__":
    main()
