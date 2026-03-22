import torch
import numpy as np
import logging
from typing import Union

from prism_sdk.networks.efficientnet import SecureEfficientNet
from prism_sdk.networks.inception_resnet import InceptionResNet

logger = logging.getLogger(__name__)

class FaceEmbedder:

    def __init__(self, cfg):
        self.cfg = cfg
        if torch.cuda.is_available():
            self.device = torch.device("cuda")
        elif torch.backends.mps.is_available():
            self.device = torch.device("mps")
        else:
            self.device = torch.device("cpu")
        self.thresh = cfg.thresh

        if cfg.arch == "SecureEfficientNet" or cfg.arch == "EfficientNet":
            self.model = SecureEfficientNet(embedding_size=cfg.embedding_dim)
        elif cfg.arch == "InceptionResNet":
            self.model = InceptionResNet(embedding_size=cfg.embedding_dim)
        else:
            raise ValueError(f"Unsupported architecture: {cfg.arch}")

        if cfg.model_path:
            self._load_weights(cfg.model_path)

        self.model.to(self.device)
        self.model.eval()

    def _load_weights(self, path: str):
        try:
            state_dict = torch.load(path, map_location=self.device)
            
            new_state_dict = {}
            for k, v in state_dict.items():
                clean_k = k.replace("network.", "") if k.startswith("network.") else k
                new_state_dict[clean_k] = v
            
            self.model.load_state_dict(new_state_dict, strict=False)
            logger.info(f"Loaded weights from {path}")
        except Exception as e:
            raise RuntimeError(f"Failed to load model weights from {path}: {str(e)}")

    def _preproc_imagenet(self, img: Union[np.ndarray, torch.Tensor]) -> Union[np.ndarray, torch.Tensor]:
        if torch.is_tensor(img):
            img = img.float() / 255.0
            mean = torch.tensor([0.485, 0.456, 0.406], device=img.device).view(3, 1, 1)
            std = torch.tensor([0.229, 0.224, 0.225], device=img.device).view(3, 1, 1)
            # If img is [H, W, C], permute it. If [C, H, W], skip.
            if img.ndim == 3 and img.shape[2] == 3:
                img = img.permute(2, 0, 1)
            return (img - mean) / std
        else:
            img = img.astype(np.float32) / 255.0
            mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
            std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
            img = (img - mean) / std
            return img.transpose((2, 0, 1))

    def _preproc_fixed(self, img: Union[np.ndarray, torch.Tensor]) -> Union[np.ndarray, torch.Tensor]:
        if torch.is_tensor(img):
            img = img.float()
            if img.ndim == 3 and img.shape[2] == 3:
                img = img.permute(2, 0, 1)
            return (img - 127.5) / 128.0
        else:
            img = img.astype(np.float32)
            img = (img - 127.5) / 128.0
            return img.transpose((2, 0, 1))

    def forward(self, rgb_image: Union[np.ndarray, torch.Tensor], key: Union[np.ndarray, torch.Tensor]) -> np.ndarray:
        # 1. Preprocessing
        if isinstance(self.model, SecureEfficientNet):
            processed_img = self._preproc_imagenet(rgb_image)
        else:
            processed_img = self._preproc_fixed(rgb_image)

        # 2. To Tensor
        if torch.is_tensor(processed_img):
            img_tensor = processed_img.unsqueeze(0).to(self.device).float()
        else:
            img_tensor = torch.from_numpy(processed_img).unsqueeze(0).float().to(self.device)

        # 3. Handle Key
        if isinstance(key, np.ndarray):
            key_tensor = torch.from_numpy(key).float().to(self.device)
        else:
            if key is None:
                 # Should not happen based on usage, but robust fallback
                 key_tensor = torch.zeros(1).to(self.device) 
            else:
                 key_tensor = key.to(self.device)
        
        if key_tensor.ndim == 1:
            key_tensor = key_tensor.unsqueeze(0)

        # 4. Inference
        with torch.no_grad():
            if isinstance(self.model, SecureEfficientNet):
                 emb = self.model(img_tensor, key_tensor)
            else:
                 emb = self.model(img_tensor)

        emb_np = emb.cpu().numpy().squeeze()
        
        # 5. Normalize
        norm = np.linalg.norm(emb_np) + 1e-12
        return emb_np / norm

    def verify_key_compatibility(self, secure_key):
        if isinstance(self.model, SecureEfficientNet):
             return True
        return False
