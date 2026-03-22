from pathlib import Path

# Root is "Capstone/"
ROOT_DIR = Path(__file__).parent.parent 

DATA_DIR = ROOT_DIR / "storage"
KEYS_DIR = DATA_DIR / "keys"
LOGS_DIR = DATA_DIR / "logs"

NETWORKS_DIR = ROOT_DIR / "networks"
WEIGHTS_DIR = ROOT_DIR / "weights"
SCHEMA_DIR = ROOT_DIR / "schema"

def get_model_path(name: str) -> Path:
    """Resolves a weight file path."""
    return (WEIGHTS_DIR / f"{name}.pth").resolve()

def ensure_dirs():
    """Ensures critical directories exist."""
    DATA_DIR.mkdir(exist_ok=True, parents=True)
    KEYS_DIR.mkdir(exist_ok=True, parents=True)
    LOGS_DIR.mkdir(exist_ok=True, parents=True)
