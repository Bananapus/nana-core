// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script, stdJson, VmSafe} from "forge-std/Script.sol";
import {CoreDeployment, CoreDeploymentLib} from "./helpers/CoreDeploymentLib.sol";

import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {IJBPriceFeed} from "src/interfaces/IJBPriceFeed.sol";
import {JBPermissions} from "src/JBPermissions.sol";
import {JBProjects} from "src/JBProjects.sol";
import {JBPrices} from "src/JBPrices.sol";
import {JBDeadline3Hours} from "src/periphery/JBDeadline3Hours.sol";
import {JBDeadline1Day} from "src/periphery/JBDeadline1Day.sol";
import {JBDeadline3Days} from "src/periphery/JBDeadline3Days.sol";
import {JBDeadline7Days} from "src/periphery/JBDeadline7Days.sol";
import {JBMatchingPriceFeed} from "src/periphery/JBMatchingPriceFeed.sol";
import {JBChainlinkV3PriceFeed, AggregatorV3Interface} from "src/JBChainlinkV3PriceFeed.sol";
import {JBChainlinkV3SequencerPriceFeed} from "src/JBChainlinkV3SequencerPriceFeed.sol";
import {JBRulesets} from "src/JBRulesets.sol";
import {JBDirectory} from "src/JBDirectory.sol";
import {JBERC20} from "src/JBERC20.sol";
import {JBTokens} from "src/JBTokens.sol";
import {JBSplits} from "src/JBSplits.sol";
import {JBFeelessAddresses} from "src/JBFeelessAddresses.sol";
import {JBFundAccessLimits} from "src/JBFundAccessLimits.sol";
import {JBController} from "src/JBController.sol";
import {JBTerminalStore} from "src/JBTerminalStore.sol";
import {JBMultiTerminal} from "src/JBMultiTerminal.sol";

import {JBConstants} from "src/libraries/JBConstants.sol";
import {JBCurrencyIds} from "src/libraries/JBCurrencyIds.sol";

contract DeployPeriphery is Script, Sphinx {
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;

    bytes32 private DEADLINES_SALT = keccak256("JBDeadlines");

    function configureSphinx() public override {
        // TODO: Update to contain JB Emergency Developers
        sphinxConfig.projectName = "nana-core-testnet";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    /// @notice Deploys the protocol.
    function run() public {
        // Get the deployment addresses for the nana CORE for this chain.
        // We want to do this outside of the `sphinx` modifier.
        core = CoreDeploymentLib.getDeployment(vm.envOr("NANA_CORE_DEPLOYMENT_PATH", string("deployments/")));

        // Deploy the protocol.
        deploy();
    }

    function deploy() public sphinx {
        // Deploy the ETH/USD price feed.
        IJBPriceFeed feed;
        IJBPriceFeed matchingPriceFeed = new JBMatchingPriceFeed();

        // Perform the deploy for L1(s).
        if (block.chainid == 11_155_111) {
            feed = new JBChainlinkV3PriceFeed(
                AggregatorV3Interface(address(0x694AA1769357215DE4FAC081bf1f309aDC325306)), 3600 seconds
            );
        } else {
            // Perform the deploy for L2s
            AggregatorV3Interface source;

            // Optimism Sepolia
            if (block.chainid == 11_155_420) {
                source = AggregatorV3Interface(address(0x61Ec26aA57019C486B10502285c5A3D4A4750AD7));
            }
            // Base Sepolia
            else if (block.chainid == 84_532) {
                source = AggregatorV3Interface(address(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1));
            }
            // Arbitrum Sepolia
            else if (block.chainid == 421_614) {
                source = AggregatorV3Interface(address(0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165));
            } else {
                revert("Unsupported chain");
            }

            // TODO: On production these should be `JBChainlinkV3SequencerPriceFeed` but these feeds aren't available
            // for testnets.
            feed = new JBChainlinkV3PriceFeed(source, 3600 seconds);
        }

        core.prices.addPriceFeedFor(0, uint32(uint160(JBConstants.NATIVE_TOKEN)), JBCurrencyIds.USD, feed);

        // If the native asset for this chain is ether, then the conversion from native asset to ether is 1:1.
        // NOTE: We need to refactor this the moment we add a chain where its native token is *NOT* ether.
        // As otherwise prices for the `NATIVE_TOKEN` will be incorrect!
        core.prices.addPriceFeedFor(0, uint32(uint160(JBConstants.NATIVE_TOKEN)), JBCurrencyIds.ETH, matchingPriceFeed);

        // Deploy the JBDeadlines
        if (!_isDeployed(DEADLINES_SALT, type(JBDeadline3Hours).creationCode, "")) {
            new JBDeadline3Hours{salt: DEADLINES_SALT}();
        }

        if (!_isDeployed(DEADLINES_SALT, type(JBDeadline1Day).creationCode, "")) {
            new JBDeadline1Day{salt: DEADLINES_SALT}();
        }

        if (!_isDeployed(DEADLINES_SALT, type(JBDeadline3Days).creationCode, "")) {
            new JBDeadline3Days{salt: DEADLINES_SALT}();
        }

        if (!_isDeployed(DEADLINES_SALT, type(JBDeadline7Days).creationCode, "")) {
            new JBDeadline7Days{salt: DEADLINES_SALT}();
        }
    }

    function _isDeployed(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory arguments
    )
        internal
        view
        returns (bool)
    {
        address _deployedTo = vm.computeCreate2Address({
            salt: salt,
            initCodeHash: keccak256(abi.encodePacked(creationCode, arguments)),
            // Arachnid/deterministic-deployment-proxy address.
            deployer: address(0x4e59b44847b379578588920cA78FbF26c0B4956C)
        });

        // Return if code is already present at this address.
        return address(_deployedTo).code.length != 0;
    }
}
