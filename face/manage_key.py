import numpy as np
from pathlib import Path


class KeyManager:

    def __init__(self, cfg):
        self.key_dim = cfg.embedder.key_dim
        self.storage_path = Path(cfg.storage.keys)
        
        self.storage_path.mkdir(parents=True, exist_ok=True)
        print(f"KeyManager initialized. Dim: {self.key_dim}, Path: {self.storage_path}")

    def generate_key(self) -> np.ndarray:
        raw_key = np.random.randint(0, 2, size=(1, self.key_dim))
        
        norm = np.linalg.norm(raw_key, axis=1, keepdims=True)
        norm_key = raw_key / (norm + 1e-10)
        
        return norm_key.astype(np.float32).flatten()

    def save_key(self, subject_id: str, key: np.ndarray):
        file_path = self.storage_path / f"{subject_id}.npy"
        np.save(file_path, key)

    def load_key(self, subject_id: str) -> np.ndarray:
        file_path = self.storage_path / f"{subject_id}.npy"
        if not file_path.exists():
            raise FileNotFoundError(f"Key for {subject_id} not found.")
        return np.load(file_path)