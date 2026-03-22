# Node Deployment

This directory contains the production Docker configuration for individual PRISM nodes across the physical cluster.

It is synchronized to all cluster nodes by the `provision/cluster_manager.py` orchestration script during the deployment phase.

### Files
- `docker-compose.node.yaml`: The multi-container orchestrator that brings up Quorum, IPFS, Nginx, and the AI Service (kiosk/scanner).
- `Dockerfile.kiosk`: The Dockerfile used to build the `ai-service` container locally on the node, encapsulating the Python biometric application and necessary hardware interfaces.
