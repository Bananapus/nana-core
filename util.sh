#!/bin/bash

if ! command -v forge &> /dev/null
then
    echo "Could not find foundry."
    echo "Please refer to the README.md for installation instructions."
    exit
fi

help_string="Available commands:
  help, -h, --help           - Show this help message
  test:local                 - Run local tests.
  test:fork                  - Run fork tests (for use in CI).
  coverage:lcov              - Generate an LCOV test coverage report.
  deploy:ethereum-mainnet    - Deploy to Ethereum mainnet
  deploy:ethereum-sepolia    - Deploy to Ethereum Sepolia testnet
  deploy:optimism-mainnet    - Deploy to Optimism mainnet
  deploy:optimism-testnet    - Deploy to Optimism testnet
  deploy:polygon-mainnet     - Deploy to Polygon mainnet
  deploy:polygon-mumbai      - Deploy to Polygon Mumbai testnet
  check:imports              - Check for unused imports
  check:errors               - Check for unused errors
  check:unimported           - Check for unimported modules"

if [ $# -eq 0 ]
then
  echo "$help_string"
  exit
fi

case "$1" in
  "help") echo "$help_string" ;;
  "-h") echo "$help_string" ;;
  "--help") echo "$help_string" ;;
  "test:local") forge test ;;
  "test:fork") FOUNDRY_PROFILE=CI forge test ;;
  "coverage:integration") forge coverage --match-path "./src/*.sol" --report lcov --report summary ;;
  "deploy:ethereum-mainnet") source .env && forge script Deploy --chain-id 1 --rpc-url $RPC_ETHEREUM_MAINNET --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY --interactives 1 --sender $SENDER_ETHEREUM_MAINNET -vvv ;;
  "deploy:ethereum-sepolia") source .env && forge script Deploy --chain-id 11155111 --rpc-url $RPC_ETHEREUM_SEPOLIA --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY --interactives 1 --sender $SENDER_ETHEREUM_SEPOLIA -vvv ;;
  "deploy:optimism-mainnet") source .env && forge script Deploy --chain-id 420 --rpc-url $RPC_OPTIMISM_MAINNET --broadcast --verify --etherscan-api-key $OPTIMISTIC_ETHERSCAN_API_KEY --interactives 1 --sender $SENDER_OPTIMISM_MAINNET -vvv ;;
  "deploy:optimism-sepolia") source .env && forge script Deploy --chain-id 11155420 --rpc-url $RPC_OPTIMISM_SEPOLIA --broadcast --verify --etherscan-api-key $OPTIMISTIC_ETHERSCAN_API_KEY --interactives 1 --sender $SENDER_OPTIMISM_SEPOLIA -vvv ;;
  "deploy:polygon-mainnet") source .env && forge script Deploy --chain-id 137 --rpc-url $RPC_POLYGON_MAINNET --broadcast --verify --etherscan-api-key $POLYSCAN_API_KEY --interactives 1 --sender $SENDER_POLYGON_MAINNET -vvv ;;
  "deploy:polygon-mumbai") source .env && forge script Deploy --chain-id 80001 --rpc-url $RPC_POLYGON_MUMBAI --broadcast --verify --etherscan-api-key $POLYSCAN_API_KEY --interactives 1 --sender $SENDER_POLYGON_MUMBAI -vvv ;;
  "check:imports") bash ./utils/unused-imports.sh ;;
  "check:errors") python ./utils/unused-errors.py ;;
  "check:unimported") python ./utils/check-used.py ;;
  *) echo "Invalid command: $1" ;;
esac
