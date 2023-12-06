import os
from pathlib import Path
import re

directories = ["contracts", "forge_tests", "script"]

declare = re.compile(r'error\s+(\w+)\(')
emit = re.compile(r'revert\s+(\w+)\(')

for directory in directories:
    for root, _, files in os.walk(Path(directory)):
        for file in files:
            with open(Path(root, file), "r") as f:
                errors = set()
                lines = f.read().splitlines()
                for line in lines:
                    match_declare = declare.search(line)
                    if match_declare:
                        errors.add(match_declare.group(1))

                    match_emit = emit.search(line)
                    if match_emit and match_emit.group(1) in errors:
                        errors.remove(match_emit.group(1))

                if(errors):
                    print(f"Unused errors in {root}/{file}: {errors}")


