import subprocess
import csv
import time
import os
import sys
import argparse
from datetime import datetime


CONTAINER_QUORUM = "quorum-node"
CONTAINER_IPFS = "ipfs-node"
BASE_FILENAME_DEFAULT = "hardware_trace"
BASE_FILENAME_IO = "io_trace"
BASE_FILENAME_IPFS = "ipfs_trace"
INTERVAL = 1

def get_incremental_filename(base):
    counter = 1
    while os.path.exists(f"{base}_{counter}.csv"):
        counter += 1
    return f"{base}_{counter}.csv"

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
        
        # State for delta calculations
        self.last_cpu_usage_ns = 0
        self.last_system_time_ns = 0
        
        self.last_disk_read_bytes = 0
        self.last_disk_write_bytes = 0
        
        self.last_net_rx_bytes = 0
        self.last_net_tx_bytes = 0
        
        # Initialize initial readings
        self._init_readings()

    def _get_container_pid(self):
        try:
            cmd = ["docker", "inspect", "--format", "{{.State.Pid}}", self.container_name]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return int(result.stdout.strip())
        except subprocess.CalledProcessError:
            print(f"Error: Could not find PID for container '{self.container_name}'. Is it running?")
            sys.exit(1)

    def _detect_cgroup_version(self):
        if os.path.exists("/sys/fs/cgroup/cgroup.controllers"):
            return 2
        return 1

    def _resolve_paths(self):
        try:
            with open(f"/proc/{self.pid}/cgroup", "r") as f:
                cgroup_lines = f.readlines()
            
            if self.is_cgroup_v2:
                for line in cgroup_lines:
                    if line.startswith("0::"):
                        suffix = line.strip().split("::")[1]
                        base_path = f"/sys/fs/cgroup{suffix}"
                        if not self.block_io_only:
                            self.cpu_path = os.path.join(base_path, "cpu.stat")
                            self.mem_path = os.path.join(base_path, "memory.current")
                        
                        self.blkio_path = os.path.join(base_path, "io.stat")
                        return
            else:
                mount_root = "/sys/fs/cgroup"
                for line in cgroup_lines:
                    # Format: 11:memory:/docker/id...
                    parts = line.strip().split(":")
                    if len(parts) < 3: continue
                    controllers = parts[1].split(",")
                    suffix = parts[2]
                    
                    if not self.block_io_only:
                        if "cpuacct" in controllers:
                            self.cpu_path = os.path.join(mount_root, "cpuacct", suffix.lstrip("/"), "cpuacct.usage")
                            if not os.path.exists(self.cpu_path) and "cpu,cpuacct" in controllers:
                                self.cpu_path = os.path.join(mount_root, "cpu,cpuacct", suffix.lstrip("/"), "cpuacct.usage")

                        if "memory" in controllers:
                            self.mem_path = os.path.join(mount_root, "memory", suffix.lstrip("/"), "memory.usage_in_bytes")
                    
                    if "blkio" in controllers:
                         self.blkio_path = os.path.join(mount_root, "blkio", suffix.lstrip("/"), "blkio.throttle.io_service_bytes")

        except Exception as e:
            print(f"Error resolving cgroup paths: {e}")
            sys.exit(1)

        if not self.block_io_only and (not self.cpu_path or not self.mem_path):
            print("Warning: Could not determine cgroup paths for CPU or Memory.")
        
        if not self.blkio_path:
             print("Warning: Could not determine cgroup paths for Block IO.")

    def _read_cpu_ns(self):
        if not self.cpu_path: return 0
        try:
            if self.is_cgroup_v2:
                with open(self.cpu_path, "r") as f:
                    for line in f:
                        if line.startswith("usage_usec"):
                            return int(line.split()[1]) * 1000 # convert to ns
            else:
                with open(self.cpu_path, "r") as f:
                    return int(f.read().strip())
        except Exception:
            return 0
        return 0

    def _read_mem_bytes(self):
        if not self.mem_path: return 0
        try:
            with open(self.mem_path, "r") as f:
                return int(f.read().strip())
        except Exception:
            return 0
            
    def _read_blkio_bytes(self):
        r_bytes = 0
        w_bytes = 0
        if not self.blkio_path or not os.path.exists(self.blkio_path): return 0, 0
        
        try:
            with open(self.blkio_path, "r") as f:
                content = f.read()
                
            if self.is_cgroup_v2:
                for line in content.strip().split('\n'):
                     parts = line.split()
                     for p in parts:
                         if p.startswith('rbytes='):
                             r_bytes += int(p.split('=')[1])
                         elif p.startswith('wbytes='):
                             w_bytes += int(p.split('=')[1])
            else:
                for line in content.strip().split('\n'):
                    parts = line.split()
                    if len(parts) < 3: continue
                    op = parts[1]
                    val = int(parts[2])
                    if op == "Read":
                        r_bytes += val
                    elif op == "Write":
                        w_bytes += val
                        
            return r_bytes, w_bytes
        except Exception:
             return 0, 0

    def _read_net_bytes(self):
        rx = 0
        tx = 0
        path = f"/proc/{self.pid}/net/dev"
        try:
            with open(path, "r") as f:
                lines = f.readlines()
            
            for line in lines:
                if "eth0" in line:
                    data = line.split(':')[1].split()
                    rx = int(data[0])
                    tx = int(data[8])
                    return rx, tx
            
            return 0, 0
        except Exception:
            return 0, 0

    def _init_readings(self):
        if not self.block_io_only:
            self.last_cpu_usage_ns = self._read_cpu_ns()
        
        self.last_disk_read_bytes, self.last_disk_write_bytes = self._read_blkio_bytes()
        self.last_net_rx_bytes, self.last_net_tx_bytes = self._read_net_bytes()
        
        self.last_system_time_ns = time.time_ns()

    def get_stats(self):
        current_time_ns = time.time_ns()
        
        run_cpu = (0, 0)
        run_disk = (0, 0)
        run_net = (0, 0)

        time_delta = current_time_ns - self.last_system_time_ns
        if time_delta == 0: return None

        if not self.block_io_only:
             curr_cpu = self._read_cpu_ns()
             curr_mem = self._read_mem_bytes()
             
             cpu_delta = curr_cpu - self.last_cpu_usage_ns
             cpu_perc = (cpu_delta / time_delta) * 100
             mem_mb = curr_mem / (1024 * 1024)
             
             self.last_cpu_usage_ns = curr_cpu
             run_cpu = (cpu_perc, mem_mb)

        curr_r, curr_w = self._read_blkio_bytes()
        r_delta = curr_r - self.last_disk_read_bytes
        w_delta = curr_w - self.last_disk_write_bytes
        
        seconds = time_delta / 1e9
        d_r_mb = (r_delta / 1024 / 1024)
        d_w_mb = (w_delta / 1024 / 1024)
        
        self.last_disk_read_bytes = curr_r
        self.last_disk_write_bytes = curr_w
        run_disk = (d_r_mb, d_w_mb)

        curr_rx, curr_tx = self._read_net_bytes()
        rx_delta = curr_rx - self.last_net_rx_bytes
        tx_delta = curr_tx - self.last_net_tx_bytes
        
        n_rx_mb = (rx_delta / 1024 / 1024)
        n_tx_mb = (tx_delta / 1024 / 1024)
        
        self.last_net_rx_bytes = curr_rx
        self.last_net_tx_bytes = curr_tx
        run_net = (n_rx_mb, n_tx_mb)

        self.last_system_time_ns = current_time_ns
        
        return {
            "cpu": run_cpu[0],
            "mem": run_cpu[1],
            "disk_read": run_disk[0],
            "disk_write": run_disk[1],
            "net_rx": run_net[0],
            "net_tx": run_net[1]
        }

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Monitor Docker container resource usage.")
    parser.add_argument("-b", "--block-io-only", action="store_true", help="Monitor only Block usage (Disk & Net I/O).")
    parser.add_argument("-i", "--ipfs-only", action="store_true", help="Monitor only the ipfs-node container.")
    parser.add_argument("--biometrics", action="store_true", help="Monitor full biometric workflow (AI, Quorum, IPFS).")
    args = parser.parse_args()

    if args.biometrics:
        container_configs = [
            (CONTAINER_QUORUM, BASE_FILENAME_DEFAULT),
            (CONTAINER_IPFS, BASE_FILENAME_IPFS),
            ("validator-ai", "biometrics_trace")
        ]
        print("Mode: Biometric Workflow Trace (AI + Quorum + IPFS)")
    elif args.ipfs_only:
        container_configs = [(CONTAINER_IPFS, BASE_FILENAME_IPFS)]
    else:
        container_configs = [
            (CONTAINER_QUORUM, BASE_FILENAME_DEFAULT),
            (CONTAINER_IPFS, BASE_FILENAME_IPFS)
        ]
    
    monitors_with_files = []
    for container, base_name in container_configs:
        try:
            monitor = ContainerMonitor(container, block_io_only=args.block_io_only)
            filename = get_incremental_filename(base_name)
            monitors_with_files.append((container, monitor, filename))
            print(f"Monitoring: {container} -> {filename}")
        except SystemExit:
            print(f"Warning: Skipping {container} (not running)")

    if not monitors_with_files:
        print("No containers to monitor. Exiting.")
        sys.exit(1)

    if args.block_io_only:
        print("Mode: I/O Only (Disk + Net)")
    else:
        print("Mode: Full (CPU + Mem + Disk + Net)")
        
    print("Press Ctrl+C to stop.")

    file_handles = {}
    writers = {}
    for container, monitor, filename in monitors_with_files:
        fh = open(filename, mode='w', newline='')
        file_handles[container] = fh
        writers[container] = csv.writer(fh)
        
        if args.block_io_only:
            headers = ["Timestamp", "Disk_Read_MB", "Disk_Write_MB", "Net_Rx_MB", "Net_Tx_MB"]
        else:
            headers = ["Timestamp", "CPU_Percent", "Memory_Usage_MB", "Disk_Read_MB", "Disk_Write_MB", "Net_Rx_MB", "Net_Tx_MB"]
        writers[container].writerow(headers)
    
    next_run = time.monotonic()

    try:
        while True:
            timestamp = datetime.now().strftime("%H:%M:%S")
            console_parts = []
            
            for container, monitor, filename in monitors_with_files:
                stats = monitor.get_stats()
                if not stats: continue
                
                writer = writers[container]
                fh = file_handles[container]
                
                if args.block_io_only:
                    row = [
                        timestamp, 
                        f"{stats['disk_read']:.2f}", f"{stats['disk_write']:.2f}",
                        f"{stats['net_rx']:.2f}", f"{stats['net_tx']:.2f}"
                    ]
                else:
                    row = [
                        timestamp, 
                        f"{stats['cpu']:.2f}", f"{stats['mem']:.2f}",
                        f"{stats['disk_read']:.2f}", f"{stats['disk_write']:.2f}",
                        f"{stats['net_rx']:.2f}", f"{stats['net_tx']:.2f}"
                    ]
                
                writer.writerow(row)
                fh.flush()
                
                short_name = "Q" if container == CONTAINER_QUORUM else "I"
                console_parts.append(f"{short_name}: CPU {stats['cpu']:4.1f}%")
            
            print(f"[{timestamp}] {' | '.join(console_parts)}", end='\r')
            
            next_run += INTERVAL
            sleep_time = next_run - time.monotonic()
            if sleep_time > 0:
                time.sleep(sleep_time)
            
    except KeyboardInterrupt:
        for fh in file_handles.values():
            fh.close()
        print(f"\nMonitoring stopped. Files saved.")

