#!/bin/bash

# Check if an argument was provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <path_to_package.json>"
  exit 1
fi

# The first argument is the path to the package.json file
PACKAGE_JSON_PATH=$1

# Extract the package name from package.json
PACKAGE_NAME=$(grep '"name":' "$PACKAGE_JSON_PATH" | awk -F': ' '{print $2}' | tr -d '", ')

# Extract the current version from package.json
LOCAL_VERSION=$(grep '"version":' "$PACKAGE_JSON_PATH" | awk -F': ' '{print $2}' | tr -d '", ')

# Get the latest version from npm
NPM_VERSION=$(npm view $PACKAGE_NAME version)

# Compare versions
if [ "$LOCAL_VERSION" = "$NPM_VERSION" ]; then
  echo "nothing to update for $PACKAGE_NAME"
else
  # Update NPM package. 
  npm publish --access public
fi
