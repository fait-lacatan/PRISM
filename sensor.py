import time
import os
import sys
import logging
import cv2
import torch

logger = logging.getLogger(__name__)

try:
    from reference.fplib import fplib
    HARDWARE_AVAILABLE = True
except ImportError:
    HARDWARE_AVAILABLE = False
    logger.warning(" Native fplib not found. Fingerprint hardware unavailable.")
                                                 
    class fplib:
        def __init__(self, port, baud, timeout): 
            raise RuntimeError("Fingerprint hardware library (fplib) not installed")
        def init(self): return False
        def is_finger_pressed(self): return False
        def set_led(self, state): pass
        def _send_packet(self, cmd): return False
        def ser(self): pass

class FingerprintSensor:
    def __init__(self, port=None, baud=115200):
        self.baud = baud
        self.fp = None
        self.connected = False
        self.port = port

    def connect(self):
        """
        Robust connection capability:
        1. Try provided port.
        2. If None/Fail, scan common ports.
        """
        ports_to_try = [self.port] if self.port else []
                                 
        ports_to_try += ['/dev/tty.usbserial-0001', '/dev/ttyUSB0', '/dev/ttyUSB1', '/dev/ttyACM0']
        
        ports_to_try = [p for p in ports_to_try if p and os.path.exists(p)]
        ports_to_try = list(dict.fromkeys(ports_to_try))                    

        if not ports_to_try:
            logger.warning("No serial ports found on system.")

        for p in ports_to_try:
            try:
                logger.info(f"Attempting connection to Fingerprint Sensor on {p}...")
                self.fp = fplib(port=p, baud=self.baud, timeout=1)                  
                if self.fp.init():
                    self.connected = True
                    self.port = p
                    logger.info(f" Sensor connected on {self.port}")
                    return True
            except Exception as e:
                logger.debug(f"Connection to {p} failed: {e}")
        
        logger.error(" Fingerprint Sensor connection failed on all attempted ports.")
        return False

    def is_finger_pressed(self):
        if not self.connected: 
            return False
        try:
                                                             
            if hasattr(self.fp, 'ser') and self.fp.ser:
                self.fp.ser.reset_input_buffer()
        except: pass
        return self.fp.is_finger_pressed()

    def set_led(self, state):
        """Manually control the sensor LED."""
        if self.connected:
            self.fp.set_led(state)

    def disconnect(self):
        """Cleanly close the serial connection."""
        if self.connected:
            try:
                if hasattr(self.fp, 'ser') and self.fp.ser:
                    self.fp.ser.close()
                logger.info(" Fingerprint Sensor disconnected.")
            except Exception as e:
                logger.error(f"Error during Fingerprint Sensor disconnect: {e}")
            self.connected = False
            self.fp = None

    def capture(self, pipeline_instance, verbose=False):
        """
        Captures a raw image. The LED is managed automatically if not already on.
        """
        if not self.connected:
            raise Exception("Sensor not connected")
            
        if hasattr(self.fp, 'ser') and self.fp.ser:
            self.fp.ser.reset_input_buffer()

        self.fp.set_led(True)
                                               
        try:
                                  
            if self.fp._send_packet("GetRawImage"):
                                                                              
                ack = self.fp.ser.read(12)
                if len(ack) != 12 or ack[8] != 0x30: 
                    return None
                
                for _ in range(100):
                    data_check = self.fp.ser.read(1)
                    if data_check == b'\x5a':
                        if self.fp.ser.read(1) == b'\xa5': break
                    time.sleep(0.01)        
                else: 
                    return None

                expected_len = (160 * 120) + 4
                data = bytearray()
                while len(data) < expected_len:
                    chunk = self.fp.ser.read(min(expected_len - len(data), 1024))
                    if not chunk: break
                    data.extend(chunk)
                                                      
                    import gevent; gevent.sleep(0)                                   
                
                if len(data) == expected_len:
                    return pipeline_instance.preprocess(data, mode="GetRawImage")
        except Exception as e:
            logger.error(f"Capture error: {e}")
        return None

import threading
class CameraSensor:
    def __init__(self, index=None):
        self.cap = None
        self.index = index
        self.is_opened = False
        self._stop_flusher = threading.Event()
        self._flusher_thread = None
        self._active = False

    def connect(self):
        indices_to_try = [self.index] if self.index is not None else [0, 1, 2, 3]
        for idx in indices_to_try:
            try:
                temp_cap = cv2.VideoCapture(idx)
                if temp_cap.isOpened():
                    ret, frame = temp_cap.read()
                    if ret and frame is not None:
                        self.cap = temp_cap
                        self.is_opened = True
                        self.index = idx
                                                                                    
                        self.start_flusher()
                        logger.info(f" Camera connected on index {idx}")
                        return True
                    else:
                        temp_cap.release()
            except Exception as e:
                logger.debug(f"Camera index {idx} failed: {e}")
        return False

    def start_flusher(self):
        """Starts a background thread that continuously grabs frames to clear the buffer."""
        if self.is_opened and not self._flusher_thread:
            self._stop_flusher.clear()
            self._flusher_thread = threading.Thread(target=self._flusher_loop, daemon=True)
            self._flusher_thread.start()

    def _flusher_loop(self):
        while not self._stop_flusher.is_set():
            if self.cap:
                                                                                
                if not self._active:
                    self.cap.grab()
            time.sleep(0.01)                                

    def set_active(self, state):
        """Transitions between 'Warm Idle' (flushing) and 'Active' (reading)."""
        self._active = state

    def read(self):
        if not self.is_opened or self.cap is None:
            return False, None
        return self.cap.read()

    def release(self):
        self._stop_flusher.set()
        if self._flusher_thread:
            self._flusher_thread.join(timeout=1.0)
        if self.cap:
            self.cap.release()
        self.is_opened = False
        self._flusher_thread = None