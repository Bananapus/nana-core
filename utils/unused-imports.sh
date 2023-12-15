#!/bin/bash

GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

for file in $(find src/ test/ script/ -iname "*.sol"); do
    output=$(awk '# Build map of imports.
      /^import/ {

        if (match($0, /{([^}]+)}/, arr)) {
          n = split(arr[1], names, ",");
          for (i in names) {
            name = gensub(/^ *| *$/, "", "g", names[i]);
            if (name != "*") {
                imports[name] = 0;
            }
          }
        }
      }
      
      # Set found imports to 1 when found.
      {
        for (name in imports) {
          if ($0 ~ "[^a-zA-Z0-9]" name "[^a-zA-Z0-9]" || $0 ~ name "[^a-zA-Z0-9]" || $0 ~ "[^a-zA-Z0-9]" name) {
            imports[name] = 1;
          }
        }
      }
      
      # Print imports which were not found.
      END {
        for (name in imports) {
          if (imports[name] == 0) {
            print "- " name;
          }
        }
      }' "$file")

    if [ ! -z "$output" ]; then
        echo -e "${BOLD}Unused imports in ${GREEN}$file:${NC}"
        echo -e "$output"
        echo -e "==========================="
    fi
done

echo "Note: this script does not check wildcard imports."
