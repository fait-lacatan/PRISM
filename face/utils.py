# src/utils.py

import numpy as np
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Any

# --- 1. Math & Metric Helpers ---

def normalised_distance(a: np.ndarray, b: np.ndarray) -> float:
    """
    Computes the normalised Euclidean distance for Secure Triplet Loss.
    d = 0.5 * var(a - b) / (var(a) + var(b))
    """
    var_a = np.var(a)
    var_b = np.var(b)
    var_diff = np.var(a - b)
    
    # Avoid division by zero
    denominator = var_a + var_b
    if denominator == 0:
        return 0.0
        
    dist = 0.5 * var_diff / denominator
    return float(dist)

def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """
    Compute cosine similarity between two vectors.
    Returns value between -1 and 1 (1 = identical).
    """
    norm_a = np.linalg.norm(a) + 1e-9
    norm_b = np.linalg.norm(b) + 1e-9
    return float(np.dot(a, b) / (norm_a * norm_b))


# --- 2. Data Collection Helpers ---

def collect_dataset_images(root: str, min_imgs: int = 2) -> Dict[str, List[str]]:
    """
    Group dataset images by subject (LFW/CFP-style).
    Returns: { "subject_id": ["path/to/img1.jpg", ...] }
    """
    subjects = defaultdict(list)
    for p in Path(root).rglob("*.jpg"):
        subjects[p.parent.name].append(str(p))
    return {k: v for k, v in subjects.items() if len(v) >= min_imgs}


# --- 3. Evaluation Metrics ---

def calculate_metrics(raw_counts: Dict[str, Any], elapsed_time: float) -> Dict[str, Any]:
    """
    Calculates derived performance metrics from raw counts collected 
    during batch evaluation (e.g., in work.py).
    """
    # Extract raw counts and set defaults
    enroll_attempts = raw_counts.get("enroll_attempts", 0)
    verify_attempts = raw_counts.get("verify_attempts", 0)
    
    # Preprocessing Failures
    enroll_fails = (
        raw_counts.get("enroll_fails_detect", 0) + 
        raw_counts.get("enroll_fails_pad", 0) + 
        raw_counts.get("enroll_fails_align", 0)
    )
    verify_fails = (
        raw_counts.get("verify_fails_detect", 0) + 
        raw_counts.get("verify_fails_pad", 0) + 
        raw_counts.get("verify_fails_align", 0)
    )

    # PAD Metrics
    total_pad_calls = raw_counts.get("pad_calls_enroll", 0) + raw_counts.get("pad_calls_verify", 0)
    total_pad_rejects = raw_counts.get("pad_rejects_enroll", 0) + raw_counts.get("pad_rejects_verify", 0)
    
    # Matcher Metrics
    pairs_compared = raw_counts.get("pairs_compared", 0)
    pairs_failed = raw_counts.get("pairs_failed_match", 0)
    
    # 1. Failure to Enroll/Verify Rates
    fte_rate = (enroll_fails / max(1, enroll_attempts))
    ftv_rate = (verify_fails / max(1, verify_attempts))
    
    # 2. PAD False Rejection Rate (BPCER)
    pad_frr = (total_pad_rejects / max(1, total_pad_calls))
    
    # 3. Matcher False Rejection Rate
    matcher_frr = (pairs_failed / max(1, pairs_compared)) 

    # 4. System-level False Rejection Rate
    # System Success = (1 - FTV) * (1 - Matcher_FRR)
    system_dsr = (1 - ftv_rate) * (1 - matcher_frr)
    system_frr = 1 - system_dsr
    
    # 5. Latency
    avg_latency_ms = (elapsed_time / max(1, pairs_compared)) * 1000

    return {
        "FTE_rate": fte_rate,
        "FTV_rate": ftv_rate,
        "PAD_FRR": pad_frr,
        "Matcher_FRR": matcher_frr,
        "System_FRR": system_frr,
        "Avg_Latency_ms": avg_latency_ms
    }
