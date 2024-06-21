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

contract Deploy is Script, Sphinx {
    /// @notice The universal PERMIT2 address.
    IPermit2 private constant _PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    /// @notice The address that is allowed to forward calls to the terminal and controller on a users behalf.
    address private constant TRUSTED_FORWARDER = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    /// @notice The address that will manage the few privileged functions of the protocol.
    address private MANAGER;

    /// @notice The address that will own the fee-project.
    address private FEE_PROJECT_OWNER;

    /// @notice The nonce that gets used across all chains to sync deployment addresses and allow for new deployments of
    /// the same bytecode.
    uint256 private CORE_DEPLOYMENT_NONCE = 4;

    function configureSphinx() public override {
        // TODO: Update to contain JB Emergency Developers
        sphinxConfig.projectName = "nana-core-testnet";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    /// @notice Deploys the protocol.
    function run() public sphinx {
        // Set the manager, this can be changed and won't affect deployment addresses.
        MANAGER = safeAddress();
        // NOTICE: THIS IS FOR TESTNET ONLY! REPLACE!
        FEE_PROJECT_OWNER = 0x1F96512db9A74b8805d900c8e553879C0Cb8Bb2a;

        // Deploy the protocol.
        deploy();
    }

    function deploy() public sphinx {
        bytes32 _coreDeploymentSalt = keccak256(abi.encode(CORE_DEPLOYMENT_NONCE));

        JBPermissions permissions = new JBPermissions{salt: _coreDeploymentSalt}();
        JBProjects projects = new JBProjects{salt: _coreDeploymentSalt}(safeAddress(), safeAddress());
        JBDirectory directory = new JBDirectory{salt: _coreDeploymentSalt}(permissions, projects, safeAddress());
        JBSplits splits = new JBSplits{salt: _coreDeploymentSalt}(directory);
        JBRulesets rulesets = new JBRulesets{salt: _coreDeploymentSalt}(directory);
        JBPrices prices = new JBPrices{salt: _coreDeploymentSalt}(permissions, projects, directory, rulesets, safeAddress());

        directory.setIsAllowedToSetFirstController(
            address(
                new JBController{salt: _coreDeploymentSalt}({
                    permissions: permissions,
                    projects: projects,
                    directory: directory,
                    rulesets: rulesets,
                    tokens: new JBTokens{salt: _coreDeploymentSalt}(directory, new JBERC20{salt: _coreDeploymentSalt}()),
                    splits: splits,
                    fundAccessLimits: new JBFundAccessLimits{salt: _coreDeploymentSalt}(directory),
                    prices: prices,
                    trustedForwarder: TRUSTED_FORWARDER
                })
            ),
            true
        );

        JBFeelessAddresses feeless = new JBFeelessAddresses{salt: _coreDeploymentSalt}(safeAddress());

        new JBMultiTerminal{salt: _coreDeploymentSalt}({
            permissions: permissions,
            projects: projects,
            directory: directory,
            splits: splits,
            store: new JBTerminalStore{salt: _coreDeploymentSalt}({directory: directory, rulesets: rulesets, prices: prices}),
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
