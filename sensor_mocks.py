import os
import cv2
import torch
import numpy as np
import glob
import logging

logger = logging.getLogger(__name__)

class MockFingerSensor:
    def __init__(self):
        self.connected = True
        self.current_user_id = None
        self.sample_queue = []
        self.target_size = 288

    def connect(self):
        return True

    def disconnect(self):
        pass

    def set_led(self, state):
        pass

    def is_finger_pressed(self):
        return len(self.sample_queue) > 0

    def set_samples(self, user_addr, paths):
        self.current_user_id = user_addr
        self.sample_queue = list(paths)
        logger.info(f"MockFingerSensor: Loaded {len(self.sample_queue)} samples for {user_addr}")

    def capture(self, pipeline):
        if not self.sample_queue:
            return None
        
        path = self.sample_queue.pop(0)
        img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
        if img is None:
            return None
            
        h, w = img.shape
        if h != self.target_size or w != self.target_size:
            img = cv2.resize(img, (self.target_size, self.target_size))
            
        img_norm = img.astype(np.float32) / 255.0
        tensor = torch.from_numpy(img_norm).unsqueeze(0).unsqueeze(0).float().to(pipeline.device)
        return tensor

class MockCameraSensor:
    def __init__(self):
        self.is_opened = True
        self.connected = True
        self.current_frame = None

    def connect(self):
        return True

    def is_opened(self):
        return True

    def release(self):
        pass

    def set_active(self, state):
        pass

    def set_frame(self, path):
        img = cv2.imread(path)
        if img is not None:
            self.current_frame = img
        else:
            logger.error(f"MockCameraSensor: Failed to load {path}")

    def read(self):
        if self.current_frame is not None:
            return True, self.current_frame.copy()
        return False, None
