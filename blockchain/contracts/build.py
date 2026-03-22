import json
import os
from solcx import compile_standard, install_solc

def compile_contracts():
    install_solc("0.8.0")

    base_path = os.path.dirname(os.path.abspath(__file__))
    contracts_path = base_path 
    build_path = os.path.abspath(os.path.join(base_path, "../build"))
    
    os.makedirs(build_path, exist_ok=True)

    sources = {}
    for filename in os.listdir(contracts_path):
        if filename.endswith(".sol"):
            with open(os.path.join(contracts_path, filename), "r") as f:
                sources[filename] = {"content": f.read()}

    print(f"Compiling {list(sources.keys())}...")

    compiled_sol = compile_standard(
        {
            "language": "Solidity",
            "sources": sources,
            "settings": {
                "outputSelection": {
                    "*": {
                        "*": ["abi", "metadata", "evm.bytecode", "evm.sourceMap"]
                    }
                }
            },
        },
        solc_version="0.8.0",
    )

    for source_file in compiled_sol["contracts"]:
        for contract_name in compiled_sol["contracts"][source_file]:
            artifact = compiled_sol["contracts"][source_file][contract_name]
            output_file = os.path.join(build_path, f"{contract_name}.json")
            
            with open(output_file, "w") as f:
                json.dump({
                    "abi": artifact["abi"],
                    "bytecode": artifact["evm"]["bytecode"]["object"]
                }, f, indent=4)
            
            print(f"Exported: {output_file}")

if __name__ == "__main__":
    compile_contracts()
