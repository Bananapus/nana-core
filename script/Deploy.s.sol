// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script, stdJson, VmSafe} from "forge-std/Script.sol";
import {CoreDeploymentLib} from "./helpers/CoreDeploymentLib.sol";

import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {JBPermissions} from "src/JBPermissions.sol";
import {JBProjects} from "src/JBProjects.sol";
import {JBPrices} from "src/JBPrices.sol";
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

import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

contract Deploy is Script, Sphinx {
    /// @notice The universal PERMIT2 address.
    IPermit2 private constant _PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    /// @notice The address that is allowed to forward calls to the terminal and controller on a users behalf.
    string private constant TRUSTED_FORWARDER_NAME = "Juicebox";
    address private TRUSTED_FORWARDER;

    /// @notice The address that will manage the few privileged functions of the protocol.
    address private MANAGER;

    /// @notice The address that will own the fee-project.
    address private FEE_PROJECT_OWNER;

    /// @notice The nonce that gets used across all chains to sync deployment addresses and allow for new deployments of
    /// the same bytecode.
    uint256 private CORE_DEPLOYMENT_NONCE = 1;

    function configureSphinx() public override {
        // TODO: Update to contain JB Emergency Developers
        sphinxConfig.projectName = "nana-core";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    /// @notice Deploys the protocol.
    function run() public sphinx {
        // Set the manager, this can be changed and won't affect deployment addresses.
        MANAGER = safeAddress();
        // NOTICE: THIS IS FOR TESTNET ONLY! REPLACE!
        // TEMP set to be the *testing* safe for the nana-fee-project
        FEE_PROJECT_OWNER = safeAddress();

        // Deploy the protocol.
        deploy();
    }

    function deploy() public sphinx {
        TRUSTED_FORWARDER =
            address(new ERC2771Forwarder{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}(TRUSTED_FORWARDER_NAME));

        JBPermissions permissions = new JBPermissions{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}();
        JBProjects projects =
            new JBProjects{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}(safeAddress(), safeAddress());
        JBDirectory directory =
            new JBDirectory{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}(permissions, projects, safeAddress());
        JBSplits splits = new JBSplits{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}(directory);
        JBRulesets rulesets = new JBRulesets{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}(directory);
        JBPrices prices = new JBPrices{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}(
            directory, permissions, projects, safeAddress()
        );
        JBTokens tokens = new JBTokens{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}(
            directory, new JBERC20{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}()
        );

        directory.setIsAllowedToSetFirstController(
            address(
                new JBController{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}({
                    directory: directory,
                    fundAccessLimits: new JBFundAccessLimits{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}(directory),
                    prices: prices,
                    permissions: permissions,
                    projects: projects,
                    rulesets: rulesets,
                    splits: splits,
                    tokens: tokens,
                    trustedForwarder: TRUSTED_FORWARDER
                })
            ),
            true
        );

        JBFeelessAddresses feeless =
            new JBFeelessAddresses{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}(safeAddress());

        new JBMultiTerminal{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}({
            permissions: permissions,
            projects: projects,
            splits: splits,
            store: new JBTerminalStore{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}({
                directory: directory,
                rulesets: rulesets,
                prices: prices
            }),
            tokens: tokens,
            feelessAddresses: feeless,
            permit2: _PERMIT2,
            trustedForwarder: TRUSTED_FORWARDER
        });

        // If the manager is not the deployer we transfer all ownership to it.
        if (MANAGER != safeAddress() && MANAGER != address(0)) {
            directory.transferOwnership(MANAGER);
            feeless.transferOwnership(MANAGER);
            prices.transferOwnership(MANAGER);
            projects.transferOwnership(MANAGER);
        }

        // Transfer ownership to the fee project owner.
        if (FEE_PROJECT_OWNER != safeAddress() && FEE_PROJECT_OWNER != address(0)) {
            projects.safeTransferFrom(safeAddress(), FEE_PROJECT_OWNER, 1);
        }
    }
}
