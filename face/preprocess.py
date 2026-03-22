import cv2, numpy as np, torch
from facenet_pytorch import MTCNN
from PIL import Image
from typing import Optional, Dict, Any, Tuple, Union

class FaceAligner:

    _ARCFACE_SRC = np.array([
        [38.2946, 51.6963], [73.5318, 51.5014], [56.0252, 71.7366],
        [41.5493, 92.3655], [70.7299, 92.2041]
    ], dtype=np.float32)

    def __init__(self, output_size: Union[int, Tuple[int, int]] = 224):
        if isinstance(output_size, int):
            self.output_size = (output_size, output_size)
        else:
            self.output_size = output_size
            
    def align(self, img_bgr: np.ndarray, landmarks: np.ndarray) -> np.ndarray:
        tgt_w, tgt_h = self.output_size
        
        scale_x = tgt_w / 112.0
        scale_y = tgt_h / 112.0
        
        src_template = self._ARCFACE_SRC.copy()
        src_template[:, 0] *= scale_x
        src_template[:, 1] *= scale_y

        M = self._estimate_similarity_transform(landmarks, src_template)
        
        aligned = cv2.warpAffine(img_bgr, M, (tgt_w, tgt_h), borderValue=0.0)
        aligned_rgb = cv2.cvtColor(aligned, cv2.COLOR_BGR2RGB)
        return aligned_rgb

    @staticmethod
    def _estimate_similarity_transform(src_pts: np.ndarray, dst_pts: np.ndarray) -> np.ndarray:
        src_pts = np.array(src_pts, dtype=np.float32)
        dst_pts = np.array(dst_pts, dtype=np.float32)
        
        M, _ = cv2.estimateAffinePartial2D(src_pts, dst_pts, method=cv2.LMEDS)
        if M is None:
            M, _ = cv2.estimateAffinePartial2D(src_pts, dst_pts, method=cv2.RANSAC)
        if M is None:
            # Fallback: simple translation if rotation estimation fails
            src_center = np.mean(src_pts, axis=0)
            dst_center = np.mean(dst_pts, axis=0)
            tx, ty = dst_center - src_center
            M = np.array([[1, 0, tx], [0, 1, ty]], dtype=np.float32)
            
        return M

class FaceDetector:

    def __init__(self, cfg: Any = None):
        detect_cfg = cfg.detect if cfg and hasattr(cfg, 'detect') else None
        
        if torch.cuda.is_available():
            self.device = torch.device('cuda')
        elif torch.backends.mps.is_available():
            self.device = torch.device('mps')
        else:
            self.device = torch.device('cpu')
        
        min_face_size = getattr(detect_cfg, 'min_face_size', 20) if detect_cfg else 20
        thresholds = getattr(detect_cfg, 'thresholds', [0.6, 0.7, 0.7]) if detect_cfg else [0.6, 0.7, 0.7]
        factor = getattr(detect_cfg, 'factor', 0.709) if detect_cfg else 0.709
        
        self.score_thr = float(getattr(detect_cfg, 'score_thr', 0.8)) if detect_cfg else 0.8

        self.mtcnn = MTCNN(
            keep_all=False, 
            select_largest=True,
            min_face_size=min_face_size,
            thresholds=thresholds,
            factor=factor,
            post_process=False,
            device='cpu' # Force CPU for MTCNN to avoid MPS pooling bugs
        )
        print(f"FaceDetector: MTCNN on cpu (Backend: {self.device})")

    def detect(self, img_bgr: np.ndarray) -> Optional[Dict[str, Any]]:
        if img_bgr is None:
            return None

        img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        pil_img = Image.fromarray(img_rgb)

        try:
            boxes, probs, landmarks = self.mtcnn.detect(pil_img, landmarks=True)
        except Exception as e:
            print(f"MTCNN detection error: {e}")
            return None

        if boxes is None or len(boxes) == 0:
            return None

        bbox = boxes[0]
        conf = probs[0]
        kps = landmarks[0]

        if conf < self.score_thr:
            return None

        return {
            "bbox": bbox.astype(int), 
            "landmarks": kps, 
            "conf": float(conf),
            "img_rgb": img_rgb 
        }

class FacePreprocessor:

    def __init__(self, cfg: Any):
        self.detector = FaceDetector(cfg)
        
        output_size = 224
        if cfg and hasattr(cfg, 'align'):
            output_size = getattr(cfg.align, 'output_size', 224)
            
        self.aligner = FaceAligner(output_size=output_size)

    def process(self, frame_bgr: np.ndarray) -> Dict[str, Any]:
        det = self.detector.detect(frame_bgr)
        
        if det is None:
            return {"status": "fail_detect", "bbox": None}
            
        bbox = det['bbox']
        landmarks = det['landmarks']
        img_rgb = det['img_rgb']

        pad_crop = self._crop_with_margin(img_rgb, bbox, margin=0.0)
        embedder_crop = self.aligner.align(frame_bgr, landmarks)

        return {
            "status": "ok",
            "bbox": bbox,
            "conf": det['conf'],
            "pad_output": pad_crop, 
            "embedder_output": embedder_crop
        }

    def _crop_with_margin(self, img_rgb: np.ndarray, bbox: np.ndarray, margin: float) -> np.ndarray:
        h, w = img_rgb.shape[:2]
        x1, y1, x2, y2 = bbox
        
        face_w = x2 - x1
        face_h = y2 - y1
        
        m_w = int(face_w * margin)
        m_h = int(face_h * margin)
        
        x1 = max(0, x1 - m_w)
        y1 = max(0, y1 - m_h)
        x2 = min(w, x2 + m_w)
        y2 = min(h, y2 + m_h)
        
        return img_rgb[y1:y2, x1:x2]