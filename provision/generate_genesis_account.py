import os
import json
from eth_account import Account



OUTPUT_KEY_PATH = "storage/keys/genesis_deployer.key"
GENESIS_PATH = "blockchain/genesis.json"

DEFAULT_GENESIS = {
    "config": {
        "chainId": 1337,
        "homesteadBlock": 0,
        "eip150Block": 0,
        "eip155Block": 0,
        "eip158Block": 0,
        "byzantiumBlock": 0,
        "constantinopleBlock": 0,
        "petersburgBlock": 0,
        "isQuorum": True
    },
    "alloc": {},
    "coinbase": "0x0000000000000000000000000000000000000000",
    "difficulty": "0x0",
    "gasLimit": "0xE0000000",
    "timestamp": "0x00"
}

def generate_deployer():
    acc = Account.create()
    
    os.makedirs(os.path.dirname(OUTPUT_KEY_PATH), exist_ok=True)
    with open(OUTPUT_KEY_PATH, "w") as f:
        f.write(acc.key.hex())
    
    print(f"\n--- [GENESIS DEPLOYER GENERATED] ---")
    print(f"Address: {acc.address}")
    print(f"Key Saved to: {OUTPUT_KEY_PATH}")

    if os.path.exists(GENESIS_PATH):
        try:
            with open(GENESIS_PATH, "r") as f:
                genesis_data = json.load(f)
        except json.JSONDecodeError:
            print(f"[{GENESIS_PATH}] is invalid JSON. Overwriting with default structure.")
            genesis_data = DEFAULT_GENESIS
    else:
        print(f"[{GENESIS_PATH}] not found. Creating new file.")
        os.makedirs(os.path.dirname(GENESIS_PATH), exist_ok=True)
        genesis_data = DEFAULT_GENESIS
    
    if "alloc" not in genesis_data:
        genesis_data["alloc"] = {}

    genesis_data["alloc"][acc.address] = {
        "balance": "1000000000000000000000"
    }

    with open(GENESIS_PATH, "w") as f:
        json.dump(genesis_data, f, indent=4)
    
    print(f"Updated [alloc] in {GENESIS_PATH} with new address.")

if __name__ == "__main__":
    generate_deployer()
