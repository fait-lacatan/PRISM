# PRISM: A Privacy-Preserving and Revocable Identity System for Mitigating On-Chain Credential Irrevocability

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Security Model](https://img.shields.io/badge/Security-Threat_Model-blueviolet.svg)](THREAT_MODEL.md)

PRISM is a decentralized, zero-trust framework for biometric identity verification at the edge. By synthesizing bimodal biometrics, fuzzy extractors, and blockchain-anchored integrity, PRISM eliminates the honeypot risk of centralized biometric databases.

---

## Zero-Trust Architecture

The system operates on three core pillars of security:

- **Non-Reversible Biometrics**: Utilizing Sample-then-Lock (STL) fuzzy extraction, PRISM never stores raw biometric images or templates. It persists only helper data and cryptographic hashes, ensuring that even a full node compromise does not leak reproducible biometric data.
- **Decentralized Availability**: Identity profiles are distributed across a Private IPFS Swarm. Each kiosk acts as a storage node, ensuring content-addressed integrity and high availability without a single point of failure.
- **Immutable Governance**: All lifecycle operations (enrollment to permanent banning) are enforced by Solidity smart contracts on a private Quorum ledger. This provides a transparent, tamper-proof audit trail of every identity transaction.

## Identity Lifecycle & Data Flow

1. **Capture**: Bimodal sensors (Fingerprint + Face) capture raw data.
2. **Liveness**: The MixStyle Residual Causal model (CF-PAD) filters out presentation attacks (spoofs).
3. **Transformation**: Biometric features are converted into stable cryptographic keys via HKDF, salted with the kiosk's `master_seed` and the user's DID.
4. **Persistence**: Encrypted profiles are pushed to IPFS; the resulting CID (Content Identifier) is anchored to the Quorum blockchain via `Registry.sol`.

## Installation

```bash
# Clone the repository
git clone https://github.com/fait-lacatan/PRISM.git
cd PRISM

# Install Python dependencies
pip install -r requirements.txt

# Download external model weights and source files (see reference/ READMEs)
```

> **Note**: The `reference/` submodules (CFPAD, JIPNet, fplib) require manual download of model files and source code from their original repositories. See each `reference/*/README.md` for setup instructions.

## Usage

### Local Simulation

```bash
cd provision/simulation
docker compose -f docker-compose.simulation.yaml up -d
```

### Physical Cluster Deployment

```bash
# Deploy kiosk nodes to physical devices over LAN
python3 provision/cluster_manager.py deploy

# Compile and deploy identity smart contracts
python3 deploy.py

# Provision cryptographic identity keys across the cluster
python3 provision/cluster_manager.py provision-identities
```

## Project Structure

```text
PRISM/
├── backend.py              # Core application server (biometrics, identity CRUD)
├── bridge.py               # Blockchain event bridge
├── deploy.py               
├── indexer.py              
├── kiosk.py                
├── sensor.py               
├── instrumentation.py      
├── blockchain/             # Solidity contracts
├── core/                   # Shared configuration loader
├── face/                   # Face preprocessing, deep embedding, and key management
├── finger/                 # Fingerprint extraction and fuzzy commitment
├── networks/               
├── provision/              # Cluster orchestration
├── reference/              
├── schema/                 
└── web-react/              
```

## Documentation

| Document | Contents |
|:---------|:---------|
| [THREAT_MODEL.md](THREAT_MODEL.md) | Key hierarchy, access control matrix, audit trail, and integrated threat model |
| [provision/README.md](provision/README.md) | Cluster orchestration and node deployment guide |
| [blockchain/README.md](blockchain/README.md) | Smart contract architecture and Quorum configuration |

## Acknowledgments

PRISM builds upon the following open-source projects for its biometric processing pipeline:

| Component | Repository | Usage |
|:----------|:-----------|:------|
| **CF-PAD** | [meilfang/CF-PAD](https://github.com/meilfang/CF-PAD) | MixStyle Residual Causal model for presentation attack detection |
| **JIPNet** | [XiongjunGuan/JIPNet](https://github.com/XiongjunGuan/JIPNet) | DeepPrint and RidgeNet architectures for fingerprint feature extraction |
| **fplib** | [Ribin-Baby/fplib-GT521Fx2](https://github.com/Ribin-Baby/fplib-GT521Fx2) | GT-521Fx2 fingerprint sensor module interface and minutiae extraction |

## License

Apache License 2.0
