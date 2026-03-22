# Simulation Environment

These simulation utilities allow you to deploy a virtualized version of the PRISM cluster using Docker for testing and development.
## Prerequisites

To run this simulation, you must generate the necessary cluster secrets and configuration files. Do **NOT** commit these generated files to version control. 

Required files in this directory:
- `swarm.key` — IPFS private swarm key
- `static-nodes.json` — Static peer discovery for the Quorum network
- `nodekeys/nodekey1` to `nodekey4` — Individual node keys for the 4 Quorum validators

> **Important:** This simulation environment *only* boots the infrastructure layers (Quorum validators and IPFS nodes). It does **not** boot the `ai-service` (Kiosk/Scanner). Additionally, the node IP addresses defined within `docker-compose.simulation.yaml` (currently mapped to the `172.16.250.x` subnet) are hardcoded for the simulation bridge network and **must be adjusted** depending on your specific local networking or usage context if you alter the Docker bridge settings.

You can generate these by running the PRISM cluster setup script:
```bash
python provision/cluster_manager.py setup
```
Then, copy the generated testing artifacts from `provision/dist/` into this simulation folder.

