// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script, stdJson, VmSafe} from "forge-std/Script.sol";
import {CoreDeployment, CoreDeploymentLib} from "./helpers/CoreDeploymentLib.sol";

import {JBChainlinkV3PriceFeed, AggregatorV3Interface} from "src/JBChainlinkV3PriceFeed.sol";
import {JBChainlinkV3SequencerPriceFeed} from "src/JBChainlinkV3SequencerPriceFeed.sol";
import {IJBPriceFeed} from "src/interfaces/IJBPriceFeed.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {JBCurrencyIds} from "src/libraries/JBCurrencyIds.sol";

contract DeployUSDCFeeds is Script, Sphinx {
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;

    uint256 CORE_DEPLOYMENT_NONCE = 1;

    function configureSphinx() public override {
        sphinxConfig.projectName = "nana-core";
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
        // The price feed.
        IJBPriceFeed feed;
        address usdc;

        // L1(s).
        if (block.chainid == 1) {
            usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
            feed = new JBChainlinkV3PriceFeed(
                AggregatorV3Interface(address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6)), 86_400 seconds
            );
        }

        if (block.chainid == 11_155_111) {
            usdc = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
            feed = new JBChainlinkV3PriceFeed(
                AggregatorV3Interface(address(0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E)), 86_400 seconds
            );
        }

        // L2(s).
        // Same as the chainlink example grace period.
        uint256 L2GracePeriod = 3600 seconds;

        // Optimism.
        if (block.chainid == 10) {
            usdc = address(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
            feed = new JBChainlinkV3SequencerPriceFeed({
                feed: AggregatorV3Interface(0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3),
                threshold: 86_400 seconds,
                sequencerFeed: AggregatorV2V3Interface(0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389),
                gracePeriod: L2GracePeriod
            });
        }

        // Optimism Sepolia.
        if (block.chainid == 11_155_420) {
            usdc = address(0x5fd84259d66Cd46123540766Be93DFE6D43130D7);
            feed = new JBChainlinkV3PriceFeed(
                AggregatorV3Interface(address(0x6e44e50E3cc14DD16e01C590DC1d7020cb36eD4C)), 86_400 seconds
            );
        }

        // Base.
        if (block.chainid == 8453) {
            usdc = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
            feed = new JBChainlinkV3SequencerPriceFeed({
                feed: AggregatorV3Interface(0x7e860098F58bBFC8648a4311b374B1D669a2bc6B),
                threshold: 86_400 seconds,
                sequencerFeed: AggregatorV2V3Interface(0xBCF85224fc0756B9Fa45aA7892530B47e10b6433),
                gracePeriod: L2GracePeriod
            });
        }

        // Base Sepolia.
        if (block.chainid == 84_532) {
            usdc = address(0x036CbD53842c5426634e7929541eC2318f3dCF7e);
            feed = new JBChainlinkV3PriceFeed(
                AggregatorV3Interface(address(0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165)), 86_400 seconds
            );
        }

        // Arbitrum.
        if (block.chainid == 42_161) {
            usdc = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
            feed = new JBChainlinkV3SequencerPriceFeed({
                feed: AggregatorV3Interface(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3),
                threshold: 86_400 seconds,
                sequencerFeed: AggregatorV2V3Interface(0xFdB631F5EE196F0ed6FAa767959853A9F217697D),
                gracePeriod: L2GracePeriod
            });
        }

        // Arbitrum Sepolia.
        if (block.chainid == 421_614) {
            usdc = address(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d);
            feed = new JBChainlinkV3PriceFeed(
                AggregatorV3Interface(address(0x0153002d20B96532C639313c2d54c3dA09109309)), 86_400 seconds
            );
        }

        if (address(feed) == address(0) || usdc == address(0)) {
            revert("Unsupported chain");
        }

        // Make sure that the USDC address contains code, otherwise its not the correct address.
        require(usdc.code.length > 0, "Invalid USDC address");

        // Sanity check, fetch the feed price.
        require(feed.currentUnitPrice(6) > 0, "Invalid price feed");

        // Add the price feed.
        // This is [UnitCurrency]/[PricingCurrency].
        core.prices.addPriceFeedFor({
            projectId: 0,
            pricingCurrency: JBCurrencyIds.USD,
            unitCurrency: uint32(uint160(usdc)),
            feed: feed
        });
    }
}
