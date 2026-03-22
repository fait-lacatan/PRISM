"""
CF-PAD Model Runtime

This module provides the runtime environment and inference code for the CF-PAD model.
The underlying model implementation (`MixStyleResCausalModel`) and its dependencies
are based on the original CF-PAD repository: 
https://github.com/meilfang/CF-PAD/tree/main

Users must ensure the reference model files are present in `reference/CFPAD/setup/`.
"""
import torch, numpy as np
from torchvision import transforms
from types import SimpleNamespace
from typing import Any

try:
    from reference.CFPAD.setup import MixStyleResCausalModel
except ImportError:
    MixStyleResCausalModel = None

class CFPADRuntime:
    MEAN = [0.485, 0.456, 0.406]
    STD = [0.229, 0.224, 0.225]

    def __init__(self, config: Any, device='cpu'):
        print(f"Loading CF-PAD model from: {config.model_path}")
        self.device = torch.device(device)
        self.config = config

        self.pad_model = MixStyleResCausalModel(
            model_name='resnet18', pretrained=False, num_classes=2, ms_layers=[]
        )
        
        try:
            checkpoint = torch.load(self.config.model_path, map_location=self.device)
            
            if isinstance(checkpoint, dict) and 'state_dict' in checkpoint:
                state_dict = checkpoint['state_dict']
            else:
                state_dict = checkpoint
            
            new_state_dict = {}
            for k, v in state_dict.items():
                name = k[7:] if k.startswith('module.') else k 
                new_state_dict[name] = v
            
            self.pad_model.load_state_dict(new_state_dict)
            
            if self.device.type != 'cpu':
                 self.pad_model = torch.nn.DataParallel(self.pad_model)
                 
            self.pad_model.to(self.device).eval()
            print("CF-PAD model loaded successfully.")

        except Exception as e:
            print(f"Error loading CF-PAD weights: {e}")
            raise e
        
        self.transform = transforms.Compose([
            transforms.ToTensor(),
            transforms.Resize((224, 224), antialias=True),
            transforms.Normalize(mean=self.MEAN, std=self.STD)
        ])

    def predict(self, face_crop_rgb: np.ndarray) -> Any: 
        if face_crop_rgb is None or face_crop_rgb.size == 0:
            return SimpleNamespace(
                score=-1.0, 
                decision=False,
                threshold=self.config.tau, 
                extras={'error': 'Empty face crop'}
            )

        if face_crop_rgb.dtype != np.uint8:
            face_crop_rgb = face_crop_rgb.astype(np.uint8)

        tensor_input = self.transform(face_crop_rgb).unsqueeze(0).to(self.device)

        with torch.no_grad():
            output = self.pad_model(tensor_input, cf=None)

        score = output.softmax(dim=1)[0, 1].item()
        decision = bool(score > self.config.tau)
        
        return SimpleNamespace(
            score=score, 
            decision=decision, 
            threshold=self.config.tau,
            extras={}
        )