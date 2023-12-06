import os
from pathlib import Path

directories = ["contracts", "forge_tests", "script"]

contract_names = set()
for directory in directories:
    for root, dirs, files in os.walk(Path(directory)):
        for file in files:
            contract_names.add(file)

found = set()
for directory in directories:
    for root, _, files in os.walk(Path(directory)):
        for file in files:
            with open(Path(root, file), "r") as f:
                content = f.read()
                for name in contract_names:
                    if name in content:
                        found.add(name)

print(f"Did not find explicit imports for: {contract_names.difference(found)}")
print("Note: those files may be used in wildcard imports, or may be surface-level contracts. Check carefully.")
