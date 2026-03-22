# Provisioning & Orchestration

The `provision/` directory serves as the command center for deploying, configuring, and managing the PRISM Decentralized Identity architecture across a physical cluster of nodes.

This directory abstracts away the complexity of bootstrapping blockchain nodes, IPFS swarms, and biometric services, giving administrators a unified interface to control the entire network.

---

## Directory Structure

```text
provision/
├── cluster_manager.py          # Core file for managing the cluster
├── distribute_configs.py       
├── generate_genesis_account.py # Bootstraps the deployer Ethereum account
├── monitor.py                  # Node-level cgroup telemetry and resource tracing
├── network_config.yaml         
├── node_control.py             
├── remote_setup.py             
├── setup_cluster.py            
├── setup_node.py               
│
├── deployment/                 # Production Docker templates
│   └── node/                   # Node orchestration files (docker-compose & Dockerfile)
│
└── simulation/                 
    └── README.md               
```

---

## Managing the Cluster

Administrators should interact almost exclusively with `cluster_manager.py`. It reads from `network_config.yaml` and executes remote commands across the cluster via SSH.

### Key Commands

- **Setup & Deployment**
  - `python cluster_manager.py setup`: Generates all cryptographic material (Node keys, Swarm keys) and the Ethereum genesis state block.
  - `python cluster_manager.py distribute`: Securely copies (`scp`) the generated configurations to all physical nodes.
  - `python cluster_manager.py provision`: Installs required system dependencies on the nodes over SSH.
  - `python cluster_manager.py deploy`: Deploys the PRISM Smart Contracts to the blockchain.
  
- **Identity & Synchronization**
  - `python cluster_manager.py provision-identities`: Generates unique cryptographic identities for each node and registers their permissions on-chain.
  - `python cluster_manager.py peer-ipfs`: Automatically meshes the IPFS nodes together into a private decentralized storage network.

- **Lifecycle Control**
  - `python cluster_manager.py start-all`: Boots the PRISM containers (Quorum, IPFS, AI Web Service) on all nodes.
  - `python cluster_manager.py stop-all`: Halts the cluster containers.
  - `python cluster_manager.py status`: Retrieves real-time status of the Docker containers across the network.
  - `python cluster_manager.py clean-all`: **[Destructive]** Wipes blockchain state, IPFS storage, and localized keys from all nodes.

---

## Configuration Management

### `network_config.yaml`
This file maps logical node IDs (e.g., `1`, `2`, `3`, `4`) to their respective static IP addresses and SSH login credentials. 

All scripts within the `provision/` subsystem consume this file to determine where to direct network commands. If a node's IP address changes, it only needs to be updated here.

---

## Node Internals

While `cluster_manager.py` loops over the network natively, it relies on passing scripts to the individual machines.

- **`node_control.py`**: Transferred to the nodes during provisioning. It manages localized tasks like starting or stopping the `docker-compose.node.yaml` services.
- **`setup_node.py`**: Binds the node's individual secrets and prepares its local environment prior to container launch.
- **`monitor.py`**: A telemetry script running on the edge nodes that traces system-level CPU/Memory/Network consumption using cgroup hooks.

---

## Simulated vs. Physical Environments

- **Physical Deployment**: Primarily managed via `cluster_manager.py` targeting a cluster of mini PCs on a LAN.
- **Simulation**: If you lack physical hardware, you can test the logical network (Quorum + IPFS) by navigating to the `simulation/` directory and following the sandbox documentation there. The simulation uses distinct Docker compose architectures to emulate the network bridging on a single host machine.
