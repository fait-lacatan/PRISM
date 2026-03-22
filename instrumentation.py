import time
import logging
import threading
import psutil
import csv
import os
import atexit
import subprocess
import json
from datetime import datetime

logger = logging.getLogger("INSTRUMENTATION")

PROC_ROOT = "/host/proc" if os.path.exists("/host/proc") else "/proc"
logger.info(f" Using PROC_ROOT: {PROC_ROOT}")

class ContainerMonitor:
    def __init__(self, container_name, block_io_only=False):
        self.container_name = container_name
        self.block_io_only = block_io_only
        self.pid = self._get_container_pid()
        self.cgroup_version = self._detect_cgroup_version()
        self.cpu_path = None
        self.mem_path = None
        self.blkio_path = None
        self.is_cgroup_v2 = (self.cgroup_version == 2)
        self._resolve_paths()
        
        self.last_cpu_usage_ns = 0
        self.last_system_time_ns = 0
        self.last_disk_read_bytes = 0
        self.last_disk_write_bytes = 0
        self.last_net_rx_bytes = 0
        self.last_net_tx_bytes = 0
        self._init_readings()
        logger.info(f" Monitor for {container_name} initialized. PID: {self.pid}, V2: {self.is_cgroup_v2}")
        if self.pid:
            logger.info(f" Paths: CPU={self.cpu_path}, MEM={self.mem_path}, IO={self.blkio_path}")

    def _get_container_pid(self):
        try:
                                                                                        
            cmd = ["curl", "--unix-socket", "/var/run/docker.sock", 
                   f"http://localhost/containers/{self.container_name}/json"]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            data = json.loads(result.stdout)
                                                              
            self.container_id = data.get("Id", "")
            return int(data.get("State", {}).get("Pid", 0))
        except Exception as e:
            logger.error(f"Failed to get PID for {self.container_name}: {e}")
            return None

    def _detect_cgroup_version(self):
        return 2 if os.path.exists("/sys/fs/cgroup/cgroup.controllers") else 1

    def _resolve_paths(self):
        if not self.pid: return
        try:
            base_path = None
            
            if self.is_cgroup_v2 and hasattr(self, 'container_id') and self.container_id:
                possible_paths = [
                    f"/sys/fs/cgroup/system.slice/docker-{self.container_id}.scope",
                    f"/sys/fs/cgroup/docker/{self.container_id}",
                    "/sys/fs/cgroup"                
                ]
                for p in possible_paths:
                    if os.path.exists(os.path.join(p, "cpu.stat")):
                        base_path = p
                        break

            if not base_path:
                cgroup_file = os.path.join(PROC_ROOT, str(self.pid), "cgroup")
                if os.path.exists(cgroup_file):
                    with open(cgroup_file, "r") as f:
                        cgroup_lines = f.readlines()
                    if self.is_cgroup_v2:
                        for line in cgroup_lines:
                            if "::" in line:
                                suffix = line.strip().split("::")[-1]
                                                                                                
                                if suffix.startswith("/.."):
                                    suffix = suffix[3:]              
                                p = f"/sys/fs/cgroup{suffix}"
                                if os.path.exists(os.path.join(p, "cpu.stat")):
                                    base_path = p
                                    break
                    else:
                                  
                        mount_root = "/sys/fs/cgroup"
                        for line in cgroup_lines:
                            parts = line.strip().split(":")
                            if len(parts) >= 3:
                                controllers, suffix = parts[1].split(","), parts[2]
                                if not self.block_io_only:
                                    if "cpuacct" in controllers: self.cpu_path = os.path.join(mount_root, "cpuacct", suffix.lstrip("/"), "cpuacct.usage")
                                    if "memory" in controllers: self.mem_path = os.path.join(mount_root, "memory", suffix.lstrip("/"), "memory.usage_in_bytes")
                                if "blkio" in controllers: self.blkio_path = os.path.join(mount_root, "blkio", suffix.lstrip("/"), "blkio.throttle.io_service_bytes")

            if base_path:
                if self.is_cgroup_v2:
                    if not self.block_io_only:
                        self.cpu_path = os.path.join(base_path, "cpu.stat")
                        self.mem_path = os.path.join(base_path, "memory.current")
                    self.blkio_path = os.path.join(base_path, "io.stat")
        except Exception as e:
            logger.error(f"Error resolving paths for {self.container_name}: {e}")

    def _read_cpu_ns(self):
        if not self.cpu_path: return 0
        try:
            if self.is_cgroup_v2:
                with open(self.cpu_path, "r") as f:
                    for line in f:
                        if line.startswith("usage_usec"): return int(line.split()[1]) * 1000
            else:
                with open(self.cpu_path, "r") as f: return int(f.read().strip())
        except: return 0
        return 0

    def _read_mem_bytes(self):
        if not self.mem_path: return 0
        if not os.path.exists(self.mem_path):
            logger.debug(f"Memory path missing: {self.mem_path}")
            return 0
        try:
            with open(self.mem_path, "r") as f: 
                val = f.read().strip()
                if not val: return 0
                return int(val)
        except Exception as e:
            logger.debug(f"Failed to read memory for {self.container_name}: {e}")
            return 0

    def _read_blkio_bytes(self):
        r, w = 0, 0
        if not self.blkio_path or not os.path.exists(self.blkio_path): return 0, 0
        try:
            with open(self.blkio_path, "r") as f: content = f.read()
            if self.is_cgroup_v2:
                for line in content.strip().split('\n'):
                    parts = line.split()
                    for p in parts:
                        if p.startswith('rbytes='): r += int(p.split('=')[1])
                        elif p.startswith('wbytes='): w += int(p.split('=')[1])
            else:
                for line in content.strip().split('\n'):
                    parts = line.split()
                    if len(parts) < 3: continue
                    if parts[1] == "Read": r += int(parts[2])
                    elif parts[1] == "Write": w += int(parts[2])
            return r, w
        except: return 0, 0

    def _read_net_bytes(self):
        if not self.pid: return 0, 0
        try:
            net_dev_file = os.path.join(PROC_ROOT, str(self.pid), "net", "dev")
            with open(net_dev_file, "r") as f:
                for line in f:
                    if "eth0" in line:
                        data = line.split(':')[1].split()
                        return int(data[0]), int(data[8])
        except: pass
        return 0, 0

    def _init_readings(self):
        self.last_cpu_usage_ns = self._read_cpu_ns()
        self.last_disk_read_bytes, self.last_disk_write_bytes = self._read_blkio_bytes()
        self.last_net_rx_bytes, self.last_net_tx_bytes = self._read_net_bytes()
        self.last_system_time_ns = time.time_ns()

    def get_stats(self):
                                                           
        if not self.pid:
            self.pid = self._get_container_pid()
            if self.pid:
                self._resolve_paths()
                self._init_readings()
        
        if not self.pid: return None
        now = time.time_ns()
        dt = now - self.last_system_time_ns
        if dt == 0: return None
        
        cpu_ns = self._read_cpu_ns()
        mem_bytes = self._read_mem_bytes()
        dr, dw = self._read_blkio_bytes()
        nr, nt = self._read_net_bytes()
        
        stats = {
            "cpu": ((cpu_ns - self.last_cpu_usage_ns) / dt) * 100,
            "mem_mb": mem_bytes / (1024 * 1024),
            "disk_read_mb": (dr - self.last_disk_read_bytes) / (1024 * 1024),
            "disk_write_mb": (dw - self.last_disk_write_bytes) / (1024 * 1024),
            "net_rx_mb": (nr - self.last_net_rx_bytes) / (1024 * 1024),
            "net_tx_mb": (nt - self.last_net_tx_bytes) / (1024 * 1024)
        }
        
        self.last_cpu_usage_ns, self.last_system_time_ns = cpu_ns, now
        self.last_disk_read_bytes, self.last_disk_write_bytes = dr, dw
        self.last_net_rx_bytes, self.last_net_tx_bytes = nr, nt
        return stats

class FieldLogger:
    """
    Singleton-style logger for Field Test metrics.
    Writes to:
    - logs/field_test/latency.csv
    - logs/field_test/reliability.csv
    - logs/field_test/resources.csv
    """
    _instance = None
    
    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(FieldLogger, cls).__new__(cls)
        return cls._instance

    def __init__(self, log_dir="storage/logs/field_test"):
        if hasattr(self, 'initialized'): return
        self.log_dir = log_dir
        os.makedirs(log_dir, exist_ok=True)
        
        self.latency_file = os.path.join(log_dir, "latency.csv")
        self.reliability_file = os.path.join(log_dir, "reliability.csv")
        self.resource_file = os.path.join(log_dir, "system_trace.csv")
        
        self._init_csv(self.latency_file, ["timestamp", "operation_id", "step", "duration_ms", "status", "metadata"])
        self._init_csv(self.reliability_file, ["timestamp", "operation_id", "type", "success", "error_reason", "metadata"])
        
        h = ["timestamp", "phase", "local_cpu", "local_mem_mb"]
        for c in ["quorum", "ipfs", "ai"]:
            h += [f"{c}_cpu", f"{c}_mem_mb", f"{c}_disk_r_mb", f"{c}_disk_w_mb", f"{c}_net_rx_mb", f"{c}_net_tx_mb"]
        self._init_csv(self.resource_file, h)
        
        self.active_timers = {}
        self.lock = threading.Lock()
        
        self.monitors = {
            "quorum": ContainerMonitor("quorum-node"),
            "ipfs": ContainerMonitor("ipfs-node"),
            "ai": ContainerMonitor("validator-ai")
        }
        
        self.current_phase = "IDLE"
        self.session_active = False
        self.monitoring = True
        self.monitor_thread = threading.Thread(target=self._monitor_resources, daemon=True)
        self.monitor_thread.start()
        
        self.initialized = True
        logger.info(f" FieldLogger initialized in {log_dir}")

    def start_session(self, operation_id):
        self.session_active = True
        self.current_phase = "START"
        logger.info(f" Monitoring Session Started: {operation_id}")

    def stop_session(self):
        self.session_active = False
        self.current_phase = "IDLE"
        logger.info(" Monitoring Session Stopped.")

    def set_phase(self, phase_name):
        self.current_phase = phase_name
        logger.info(f" Phase Change: {phase_name}")

    def _init_csv(self, filepath, headers):
        if not os.path.exists(filepath):
            with open(filepath, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow(headers)

    def _monitor_resources(self):
        process = psutil.Process(os.getpid())
        while self.monitoring:
            if not self.session_active:
                time.sleep(1)
                continue
            
            try:
                                  
                cpu = process.cpu_percent()
                mem = process.memory_info().rss / (1024 * 1024)
                
                row = [datetime.now().isoformat(), self.current_phase, round(cpu, 2), round(mem, 2)]
                
                for name in ["quorum", "ipfs", "ai"]:
                    stats = self.monitors[name].get_stats()
                    if stats:
                        row += [
                            round(stats["cpu"], 2), round(stats["mem_mb"], 2),
                            round(stats["disk_read_mb"], 2), round(stats["disk_write_mb"], 2),
                            round(stats["net_rx_mb"], 2), round(stats["net_tx_mb"], 2)
                        ]
                    else:
                        row += [0] * 6
                
                with open(self.resource_file, 'a', newline='') as f:
                    writer = csv.writer(f)
                    writer.writerow(row)
            except Exception as e:
                logger.error(f"Resource monitor error: {e}")
            
            time.sleep(1)                                           

    def start_timer(self, operation_id, step_name):
        key = f"{operation_id}:{step_name}"
        with self.lock:
            self.active_timers[key] = time.time()

    def stop_timer(self, operation_id, step_name, status="OK", metadata=""):
        key = f"{operation_id}:{step_name}"
        duration = 0
        with self.lock:
            if key in self.active_timers:
                start = self.active_timers.pop(key)
                duration = round((time.time() - start) * 1000, 2)     
        
        with open(self.latency_file, 'a', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([
                datetime.now().isoformat(), 
                operation_id, 
                step_name, 
                duration, 
                status, 
                metadata
            ])
        return duration

    def log_success(self, operation_id, op_type, metadata=""):
        with open(self.reliability_file, 'a', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([
                datetime.now().isoformat(),
                operation_id,
                op_type,
                True,
                "",
                metadata
            ])

    def log_failure(self, operation_id, op_type, reason, metadata=""):
        with open(self.reliability_file, 'a', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([
                datetime.now().isoformat(),
                operation_id,
                op_type,
                False,
                str(reason),
                metadata
            ])

    def stop(self):
        self.monitoring = False

logger_instance = FieldLogger()
