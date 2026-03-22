import sqlite3
import time
import logging
import json
from web3 import Web3
from prism_sdk.agent import IdentityAgent
from core.settings import sys_config

logging.basicConfig(level=logging.INFO, format='%(asctime)s - INDEXER - %(levelname)s - %(message)s')
logger = logging.getLogger("INDEXER")

DB_PATH = "storage/index.db"

SYNC_CHUNK_SIZE = 500

class PrismIndexer:
    def __init__(self, agent=None, config_path=None):
        self.agent = agent or IdentityAgent(config_path=config_path if config_path else "blockchain/master.yaml") 
        self.conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        self.ensure_schema()
        self._contracts_cached = False
        self._contract_reg = None
        self._contract_att = None

    def _ensure_contracts(self):
        """Lazily load and cache contract objects (ABI read once, not per-sync)."""
        if self._contracts_cached:
            return
        if not self.agent.w3:
            return
        try:
            self._contract_reg = self.agent.w3.eth.contract(
                address=self.agent.config['contracts']['registry']['address'],
                abi=json.load(open(self.agent.config['contracts']['registry']['abi_path']))['abi']
            )
            self._contract_att = self.agent.w3.eth.contract(
                address=self.agent.config['contracts']['attendance']['address'],
                abi=json.load(open(self.agent.config['contracts']['attendance']['abi_path']))['abi']
            )
            self._contracts_cached = True
            logger.info("Contracts cached (ABI loaded once)")
        except Exception as e:
            logger.error(f"Failed to cache contracts: {e}")
        
    def ensure_schema(self):
        cur = self.conn.cursor()
                                                                        
        cur.execute("""
            CREATE TABLE IF NOT EXISTS users (
                address TEXT PRIMARY KEY,
                name TEXT,
                user_id TEXT UNIQUE,
                status TEXT,
                position TEXT,
                department TEXT,
                college TEXT,
                email TEXT,
                profile_cid TEXT,
                enrollment_device TEXT,
                indexed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS sync_state (
                key TEXT PRIMARY KEY,
                value INTEGER
            )
        """)
                                                                                
        try:
            cur.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_user_id ON users(user_id)")
        except sqlite3.IntegrityError:
            logger.warning(" Could not create UNIQUE index: Existing duplicate Faculty IDs found in index.db")
        
        cur.execute("""
            CREATE TABLE IF NOT EXISTS attendance_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_address TEXT,
                device_id TEXT,
                timestamp INTEGER,
                verified BOOLEAN,
                ipfs_cid TEXT,
                status TEXT
            )
        """)
        
        cur.execute("""
            CREATE TABLE IF NOT EXISTS user_schedules (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_address TEXT NOT NULL,
                schedule_type TEXT DEFAULT 'fixed',
                time_blocks TEXT,
                grace_minutes INTEGER DEFAULT 15,
                effective_from TEXT,
                created_by TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_address) REFERENCES users(address)
            )
        """)
        
        try:
            cur.execute("ALTER TABLE attendance_log ADD COLUMN device_id TEXT")
        except sqlite3.OperationalError:
            pass                 
        
        for col in ['position', 'department', 'college', 'email', 'enrollment_device']:
            try:
                cur.execute(f"ALTER TABLE users ADD COLUMN {col} TEXT")
            except sqlite3.OperationalError:
                pass                 

        cur.execute("CREATE INDEX IF NOT EXISTS idx_users_address_lower ON users(address COLLATE NOCASE)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_attendance_user ON attendance_log(user_address COLLATE NOCASE)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_attendance_ts ON attendance_log(timestamp)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_schedules_user ON user_schedules(user_address COLLATE NOCASE)")

        self.conn.commit()

    def reset_index(self):
        """Hard reset: Clears all data and resets sync block to 0."""
        try:
            with self.conn:
                cur = self.conn.cursor()
                cur.execute("DELETE FROM users")
                cur.execute("DELETE FROM attendance_log")
                                                                                         
                cur.execute("UPDATE sync_state SET value = 0 WHERE key = 'last_block'")
            logger.warning("INDEXER RESET: All data cleared and sync state reset.")
            return True
        except Exception as e:
            logger.error(f"Failed to reset indexer: {e}")
            return False

    def get_last_block(self):
        cur = self.conn.cursor()
        res = cur.execute("SELECT value FROM sync_state WHERE key='last_block'").fetchone()
        return res[0] if res else 0

    def set_last_block(self, block):
        cur = self.conn.cursor()
        cur.execute("INSERT OR REPLACE INTO sync_state (key, value) VALUES ('last_block', ?)", (block,))
        self.conn.commit()

    def generate_user_id(self):
        """
        Auto-generates a sequential user ID in format USR-XXXX.
        """
        cur = self.conn.cursor()
        res = cur.execute("SELECT COUNT(*) FROM users").fetchone()
        next_num = (res[0] if res else 0) + 1
        return f"USR-{next_num:04d}"

    def add_user(self, address, name, user_id=None, status="Active", profile_cid=None,
                 position=None, department=None, email=None, enrollment_device="Manual"):
        """
        Manually adds a user to the index without waiting for blockchain sync.
        Auto-generates user_id if not provided.
        Note: DID is NOT stored locally for security reasons.
        """
        try:
            address = address.lower()
            cur = self.conn.cursor()
                                                   
            if not user_id:
                user_id = self.generate_user_id()
            
            cur.execute("""
                INSERT OR REPLACE INTO users (address, name, user_id, status, position, department, email, profile_cid, enrollment_device)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (address, name, user_id, status, position, department, email, profile_cid or "PENDING", enrollment_device))
            self.conn.commit()
            logger.info(f"Indexed {name} with ID {user_id}")
            return user_id
        except sqlite3.IntegrityError as e:
            logger.error(f"Deduplication Error for {name} ({user_id}): {e}")
            return None
        except Exception as e:
            logger.error(f"Failed to index {address}: {e}")
            return None

    def update_user_status(self, address, status):
        """Updates user status in the local index with normalized address matching."""
        try:
            address = address.lower()
            cur = self.conn.cursor()
            cur.execute("UPDATE users SET status = ? WHERE LOWER(address) = LOWER(?)", (status, address))
            self.conn.commit()
            logger.info(f"Updated status for {address} to {status} (Normalized Sync)")
            return True
        except Exception as e:
            logger.error(f"Failed to update status for {address}: {e}")
            return False

    def update_user_metadata(self, address, email=None, department=None, position=None):
        """Updates mutable user metadata in the local index."""
        try:
            cur = self.conn.cursor()
                                                           
            fields = []
            values = []
            if email is not None:
                fields.append("email = ?")
                values.append(email)
            if department is not None:
                fields.append("department = ?")
                values.append(department)
            if college is not None:
                fields.append("college = ?")
                values.append(college)
            if position is not None:
                fields.append("position = ?")
                values.append(position)
            
            if not fields:
                return True                    
                
            values.append(address)
            query = f"UPDATE users SET {', '.join(fields)} WHERE LOWER(address) = LOWER(?)"
            
            cur.execute(query, tuple(values))
            self.conn.commit()
            logger.info(f"Updated metadata for {address}")
            return True
        except Exception as e:
            logger.error(f"Failed to update metadata for {address}: {e}")
            return False

    def lookup_user(self, query):
        """
        Finds a user by User ID or Address.
        NOTE: DID lookup removed for security - DID is not stored locally.
        Returns the User Address (str) or None.
        """
        cur = self.conn.cursor()
        query = query.strip()
        
        if query.startswith("0x") and len(query) == 42:
                                            
            res = cur.execute("SELECT address FROM users WHERE LOWER(address)=LOWER(?)", (query,)).fetchone()
            return res[0] if res else None
             
        res = cur.execute("SELECT address FROM users WHERE user_id LIKE ?", (query,)).fetchone()
        if res: return res[0]
        
        return None

    def process_event(self, event, tx_cache=None):
        """Process UserEnrolled Event - indexes user without storing DID locally"""
        args = event['args']
        user_addr = args['user'].lower()
        did = args['did']                                               
        info_cid_bytes = args['infoCID']
        
        logger.info(f"Processing Enrollment for address: {user_addr}")

        enrollment_device = "Unknown"
        tx_hash = event['transactionHash']
        if tx_cache and tx_hash in tx_cache:
            enrollment_device = tx_cache[tx_hash]['from']
        else:
            try:
                tx = self.agent.w3.eth.get_transaction(tx_hash)
                enrollment_device = tx['from']
            except Exception as e:
                logger.warning(f"Could not fetch enrollment device: {e}")
        
        name = 'Unknown'
        user_id = None
        college = None
        department = None
        position = None
        email = None
        
        try:
             profile_data = self.agent.resolve_profile(info_cid_bytes, user_did=did)
             if profile_data:
                 identity = profile_data.get('identity', {})
                 name = identity.get('name', 'Unknown')
                 user_id = identity.get('user_id', None)
                 college = identity.get('college', None)
                 department = identity.get('department', None)
                 position = identity.get('position', None)
                 email = identity.get('email', None)
                 logger.info(f">>> [INDEXER] Extracted from Profile - ID: {user_id}, Name: {name}, Dept: {department}, College: {college}")
             else:
                 logger.warning(f"Could not resolve profile for {user_addr} - indexing with on-chain data only")
        except Exception as e:
            logger.warning(f"Profile resolution failed for {user_addr}: {e} - indexing with on-chain data only")

        cid_str = info_cid_bytes.hex() if isinstance(info_cid_bytes, (bytes, bytearray)) else str(info_cid_bytes)
        
        try:
             cur = self.conn.cursor()

             existing = cur.execute("SELECT department, position, email, college, status FROM users WHERE LOWER(address) = LOWER(?)", (user_addr,)).fetchone()
             if existing:
                                                                                             
                 if not department and existing[0]: department = existing[0]
                 if not position and existing[1]: position = existing[1]
                 if not email and existing[2]: email = existing[2]
                 if not college and existing[3]: college = existing[3]
                                                                                                             
                 status = existing[4] or "Active"
             else:
                 status = "Active"

             cur.execute("""
                INSERT OR REPLACE INTO users (address, name, user_id, status, profile_cid, department, position, email, enrollment_device, college)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             """, (user_addr, name, user_id, status, cid_str, department, position, email, enrollment_device, college)) 
             
             logger.info(f"Indexed {name} (ID: {user_id}) enrolled by {enrollment_device}")
             
        except Exception as e:
            logger.error(f"Failed to index {user_addr}: {e}")

    def get_stats_breakdown(self):
        """
        Aggregates attendance statistics for the last 24 hours.
        """
        cur = self.conn.cursor()
        now = int(time.time())
        day_ago = now - (24 * 3600)
        
        time_filter = f"timestamp >= {day_ago}"
        
        total_query = f"SELECT COUNT(*) FROM attendance_log WHERE {time_filter}"
        total = cur.execute(total_query).fetchone()[0]
        
        personal_query = f"LOWER(device_id) = LOWER(user_address) AND device_id IS NOT 'Unknown' AND {time_filter}"
        personal = cur.execute(f"SELECT COUNT(*) FROM attendance_log WHERE {personal_query}").fetchone()[0]
        
        personal_failures = cur.execute(f"SELECT COUNT(*) FROM attendance_log WHERE ({personal_query}) AND status NOT IN ('SUCCESS', 'present')").fetchone()[0]

        kiosk_condition = f"(LOWER(device_id) != LOWER(user_address) OR device_id IS 'Unknown') AND {time_filter}"
        kiosk_rows = cur.execute(f"""
            SELECT device_id, COUNT(*) as count 
            FROM attendance_log 
            WHERE {kiosk_condition}
            GROUP BY device_id
            ORDER BY count DESC
        """).fetchall()
        
        kiosk_failures = cur.execute(f"SELECT COUNT(*) FROM attendance_log WHERE ({kiosk_condition}) AND status NOT IN ('SUCCESS', 'present')").fetchone()[0]

        kiosks = []
        for r in kiosk_rows:
            if r[0] != 'Unknown':
                kiosks.append({"id": r[0], "count": r[1]})
        
        unknown = sum(r[1] for r in kiosk_rows if r[0] == 'Unknown')
        
        kiosk_breakdown = {}
        for k in kiosks:
            kid = k['id'] or "Unknown"
            label = f"Kiosk {kid[:8]}..." if len(kid) > 8 else kid
            kiosk_breakdown[label] = k['count']
        
        successful = cur.execute(f"SELECT COUNT(*) FROM attendance_log WHERE {time_filter} AND status IN ('SUCCESS', 'present')").fetchone()[0]
        success_rate = round((successful / total * 100), 1) if total > 0 else 0
        
        return {
            "total_checkins": total,
            "successful_checkins": successful,
            "success_rate": success_rate,
            "personal_count": personal,
            "personal_failures": personal_failures,
            "kiosk_breakdown": kiosk_breakdown,
            "kiosk_failures": kiosk_failures,
            "legacy_unknown": unknown
        }

    def get_user_attendance(self, address, limit=10):
        """Fetch recent attendance logs for a specific user"""
        cur = self.conn.cursor()
        rows = cur.execute("""
            SELECT timestamp, status, ipfs_cid, verified, device_id
            FROM attendance_log 
            WHERE LOWER(user_address) = LOWER(?) 
            ORDER BY timestamp DESC 
            LIMIT ?
        """, (address, limit)).fetchall()
        
        return [
            {
                "timestamp": r[0],
                "status": r[1],
                "cid": r[2],
                "verified": bool(r[3]),
                "device_id": r[4] if len(r) > 4 else "Unknown" 
            }
            for r in rows
        ]

    def process_status_change(self, event):
        """Process StatusChanged Event (Revocation/Reactivation)"""
        args = event['args']
        user_addr = args['user'].lower()
        is_active = args['active']
        
        logger.info(f"Processing Status Change for {user_addr}: Active={is_active}")
        
        try:
            cur = self.conn.cursor()
            status = "Active" if is_active else "Revoked"
            
            cur.execute("UPDATE users SET status=? WHERE LOWER(address)=LOWER(?)", (status, user_addr))
            logger.info(f"Updated {user_addr} to {status}")
        except Exception as e:
            logger.error(f"Failed to update status for {user_addr}: {e}")

    def process_attendance(self, event, tx_cache=None, block_cache=None):
        """Process Attendance Logged Event"""
        args = event['args']
        user_addr = args['user'].lower()
        cid = args['infoCID']
        status = args['status']
        
        block_num = event['blockNumber']
        if block_cache and block_num in block_cache:
            ts = block_cache[block_num]['timestamp']
        else:
            ts = int(time.time())
            try:
                block = self.agent.w3.eth.get_block(block_num)
                ts = block['timestamp']
            except:
                pass

        device_id = "Unknown"
        tx_hash = event['transactionHash']
        if tx_cache and tx_hash in tx_cache:
            device_id = tx_cache[tx_hash]['from']
        else:
            try:
                tx = self.agent.w3.eth.get_transaction(tx_hash)
                device_id = tx['from']
            except Exception as e:
                logger.warning(f"Could not fetch tx for attendance: {e}")
        
        try:
            cur = self.conn.cursor()
                                              
            cur.execute("""
                INSERT INTO attendance_log (user_address, device_id, timestamp, verified, ipfs_cid, status)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (user_addr, device_id, ts, status == "SUCCESS", cid, status))
            logger.info(f"Logged Attendance for {user_addr} via {device_id}: {status}")
        except Exception as e:
            logger.error(f"Failed to index attendance: {e}")

    def sync_statuses(self):
        """Force reconciliation of all user statuses with on-chain data."""
        if not self.agent.w3:
            logger.error("No Blockchain Connection for status sync.")
            return False
            
        try:
            self._ensure_contracts()
            if not self._contract_reg:
                logger.error("Registry contract not available for status sync.")
                return False
            
            cur = self.conn.cursor()
            users = cur.execute("SELECT address, status FROM users").fetchall()
            
            logger.info(f"Starting deep status sync for {len(users)} users...")
            updates = 0
            
            for addr, local_status in users:
                try:
                    checksum_addr = Web3.to_checksum_address(addr)
                    profile = self._contract_reg.functions.profiles(checksum_addr).call()
                    is_active = profile[2]
                    on_chain_status = "Active" if is_active else "Revoked"
                    
                    if on_chain_status != local_status:
                        self.update_user_status(addr, on_chain_status)
                        updates += 1
                except Exception as e:
                    logger.warning(f"Could not fetch on-chain status for {addr}: {e}")
                    
            logger.info(f"Deep sync complete. Updated {updates} user statuses.")
            return True
        except Exception as e:
            logger.error(f"Status deep sync failed: {e}")
            return False

    def _batch_fetch_rpc(self, all_events):
        """Pre-fetch all unique transactions and blocks needed by events in one pass."""
        tx_cache = {}                      
        block_cache = {}                              

        needed_tx_hashes = set()
        needed_blocks = set()
        for event in all_events:
            needed_tx_hashes.add(event['transactionHash'])
            if event['event'] == 'Logged':                                   
                needed_blocks.add(event['blockNumber'])

        for tx_hash in needed_tx_hashes:
            try:
                tx_cache[tx_hash] = self.agent.w3.eth.get_transaction(tx_hash)
            except Exception as e:
                logger.debug(f"Could not pre-fetch tx {tx_hash.hex()[:16]}...: {e}")

        for block_num in needed_blocks:
            try:
                block_cache[block_num] = self.agent.w3.eth.get_block(block_num)
            except Exception as e:
                logger.debug(f"Could not pre-fetch block {block_num}: {e}")

        logger.info(f"Pre-fetched {len(tx_cache)} txs, {len(block_cache)} blocks (deduped from {len(all_events)} events)")
        return tx_cache, block_cache

    def _sync_chunk(self, from_block, to_block):
        """Sync a single chunk of blocks. Returns True on success."""
        try:
            logger.info(f"Scanning blocks {from_block} to {to_block}...")
            enroll_events = self._contract_reg.events.UserEnrolled.get_logs(from_block=from_block, to_block=to_block)
            status_events = self._contract_reg.events.StatusChanged.get_logs(from_block=from_block, to_block=to_block)
            attend_events = self._contract_att.events.Logged.get_logs(from_block=from_block, to_block=to_block)
            
            logger.info(f" Found: {len(enroll_events)} enrollments, {len(status_events)} status changes, {len(attend_events)} attendance logs")
            
            all_events = sorted(
                list(enroll_events) + list(status_events) + list(attend_events),
                key=lambda x: (x['blockNumber'], x['transactionIndex'])
            )

            if all_events:
                logger.info(f"Syncing {len(all_events)} events from blocks {from_block} to {to_block}...")
                
                tx_cache, block_cache = self._batch_fetch_rpc(all_events)

                for event in all_events:
                    if event['event'] == 'UserEnrolled':
                        self.process_event(event, tx_cache=tx_cache)
                    elif event['event'] == 'StatusChanged':
                        self.process_status_change(event)
                    elif event['event'] == 'Logged':
                        self.process_attendance(event, tx_cache=tx_cache, block_cache=block_cache)

                self.conn.commit()
            else:
                logger.info(f" No events in blocks {from_block}-{to_block}")
            
            self.set_last_block(to_block)
            return True
            
        except Exception as e:
            logger.error(f"Sync error for blocks {from_block}-{to_block}: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False

    def run_sync(self):
        """Syncs all events from the last checked block, in chunks."""
        if not self.agent.w3:
            logger.error("No Blockchain Connection.")
            return

        last_block = self.get_last_block()
        curr_block = self.agent.w3.eth.block_number
        
        if last_block >= curr_block:
            return

        self._ensure_contracts()
        if not self._contract_reg or not self._contract_att:
            logger.error("Contracts not available. Cannot sync.")
            return

        total_blocks = curr_block - last_block
        if total_blocks > SYNC_CHUNK_SIZE:
            logger.info(f"Large sync range ({total_blocks} blocks). Chunking by {SYNC_CHUNK_SIZE}...")
        
        chunk_start = last_block
        while chunk_start < curr_block:
            chunk_end = min(chunk_start + SYNC_CHUNK_SIZE, curr_block)
            if not self._sync_chunk(chunk_start, chunk_end):
                break                                                              
            chunk_start = chunk_end

    def resync_profiles(self):
        """Backfill Department/Position/Email for existing users"""
        try:
            cur = self.conn.cursor()
                                                                         
            users = cur.execute("SELECT address, profile_cid FROM users WHERE profile_cid != 'ENCRYPTED' AND profile_cid IS NOT NULL").fetchall()
            count = 0
            
            logger.info(f"Starting profile backfill for {len(users)} users...")
            
            for addr, cid_hex in users:
                try:
                                                      
                    info_cid_bytes = bytes.fromhex(cid_hex)
                    
                    did = f"did:ethr:{addr}"
                    
                    profile_data = self.agent.resolve_profile(info_cid_bytes, user_did=did)
                    
                    if profile_data:
                         identity = profile_data.get('identity', {})
                         dept = identity.get('department')
                         pos = identity.get('position')
                         email = identity.get('email')
                         
                         if dept or pos or email:
                             cur.execute("""
                                UPDATE users SET department=?, position=?, email=? WHERE address=?
                             """, (dept, pos, email, addr))
                             count += 1
                except Exception as e:
                    logger.debug(f"Backfill skip for {addr}: {e}")
                    
            self.conn.commit()
            logger.info(f"Backfilled profiles for {count} users")
            return count
        except Exception as e:
            logger.error(f"Resync error: {e}")
            return 0

    def set_user_schedule(self, user_address, schedule_data, admin_address):
        """
        Assigns or updates a schedule for a user.
        schedule_data: {schedule_type, time_blocks, grace_minutes, effective_from}
        """
        try:
            cur = self.conn.cursor()
                                                                        
            res = cur.execute("SELECT address FROM users WHERE LOWER(address) = LOWER(?)", (user_address,)).fetchone()
            if not res:
                logger.error(f"Cannot set schedule: User {user_address} not found in index.")
                return False
            
            canonical_addr = res[0]
            admin_address = admin_address if admin_address else "unknown"

            with self.conn:
                                                   
                cur.execute("DELETE FROM user_schedules WHERE user_address = ?", (canonical_addr,))
                cur.execute("""
                    INSERT INTO user_schedules (user_address, schedule_type, time_blocks, grace_minutes, effective_from, created_by)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, (
                    canonical_addr,
                    schedule_data.get('schedule_type', 'fixed'),
                    json.dumps(schedule_data.get('time_blocks', [])),
                    schedule_data.get('grace_minutes', 15),
                    schedule_data.get('effective_from'),
                    admin_address
                ))
            logger.info(f"Schedule assigned to {canonical_addr} by {admin_address}")
            return True
        except Exception as e:
            logger.error(f"Failed to set schedule for {user_address}: {e}")
            return False

    def get_user_schedule(self, user_address):
        """Returns schedule data for a user, or None if not assigned."""
        cur = self.conn.cursor()
        res = cur.execute("""
            SELECT schedule_type, time_blocks, grace_minutes, effective_from, created_by, created_at
            FROM user_schedules WHERE LOWER(user_address) = LOWER(?)
        """, (user_address,)).fetchone()
        if res:
            return {
                'schedule_type': res[0],
                'time_blocks': json.loads(res[1]) if res[1] else [],
                'grace_minutes': res[2],
                'effective_from': res[3],
                'created_by': res[4],
                'created_at': res[5]
            }
        return None

    def get_all_schedules(self):
        """Returns all user schedules with user info."""
        cur = self.conn.cursor()
        res = cur.execute("""
            SELECT u.address, u.name, u.user_id, s.schedule_type, s.time_blocks, s.grace_minutes
            FROM users u
            LEFT JOIN user_schedules s ON u.address = s.user_address
        """).fetchall()
        return [{
            'address': r[0],
            'name': r[1],
            'user_id': r[2],
            'schedule_type': r[3],
            'time_blocks': json.loads(r[4]) if r[4] else [],
            'grace_minutes': r[5]
        } for r in res]

    def get_attendance_with_status(self, user_address=None, limit=50):
        """
        Returns attendance logs with timeliness status (ON_TIME, LATE, UNSCHEDULED).
        """
        from datetime import datetime
        cur = self.conn.cursor()
        
        query = """
            SELECT a.id, a.user_address, a.timestamp, a.device_id, a.status, u.name, u.user_id, u.status, u.department, u.position, a.verified
            FROM attendance_log a
            JOIN users u ON LOWER(a.user_address) = LOWER(u.address)
        """
        params = []
        if user_address:
            query += " WHERE LOWER(user_address) = LOWER(?)"
            params.append(user_address)
        query += " ORDER BY a.timestamp DESC LIMIT ?"
        params.append(limit)
        
        rows = cur.execute(query, params).fetchall()
        result = []
        
        for row in rows:
            attendance_ts = row[2]
            addr = row[1]
            
            schedule = self.get_user_schedule(addr)
            timeliness = 'UNSCHEDULED'
            expected_time = None
            
            if schedule and schedule['time_blocks']:
                                               
                dt = datetime.fromtimestamp(attendance_ts)
                day_name = dt.strftime('%a').upper()[:3]                 
                time_str = dt.strftime('%H:%M')
                
                for block in schedule['time_blocks']:
                    if block.get('day') == day_name:
                        expected_time = block.get('start')
                        grace = schedule.get('grace_minutes', 15)
                        
                        expected_mins = int(expected_time.split(':')[0]) * 60 + int(expected_time.split(':')[1])
                        actual_mins = int(time_str.split(':')[0]) * 60 + int(time_str.split(':')[1])
                        
                        if actual_mins <= expected_mins + grace:
                            timeliness = 'ON_TIME'
                        else:
                            timeliness = 'LATE'
                        break
            
            result.append({
                'id': row[0],
                'user_address': addr,
                'timestamp': attendance_ts,
                'device_id': row[3],
                'status': row[4],
                'name': row[5],
                'user_id': row[6],
                'user_status': row[7],
                'department': row[8],
                'position': row[9],
                'timeliness': timeliness,
                'expected_time': expected_time,
                'verified': bool(row[10])                      
            })
        
        return result

    def get_user_stats(self, user_address):
        """Returns attendance statistics for a specific user."""
        attendance = self.get_attendance_with_status(user_address, limit=1000)
        total = len(attendance)
        on_time = sum(1 for a in attendance if a['timeliness'] == 'ON_TIME')
        late = sum(1 for a in attendance if a['timeliness'] == 'LATE')
        
        return {
            'total_checkins': total,
            'on_time_count': on_time,
            'late_count': late,
            'on_time_percentage': round((on_time / total * 100) if total > 0 else 0, 1)
        }

if __name__ == "__main__":
    indexer = PrismIndexer()
    while True:
        indexer.run_sync()
        time.sleep(10)                 
