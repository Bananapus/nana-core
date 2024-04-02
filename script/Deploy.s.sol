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

    function configureSphinx() public override {
        // TODO: Update to contain JB Emergency Developers
        sphinxConfig.owners = [0x26416423d530b1931A2a7a6b7D435Fac65eED27d];
        sphinxConfig.orgId = "cltepuu9u0003j58rjtbd0hvu";
        sphinxConfig.projectName = "nana-core";
        sphinxConfig.threshold = 1;
        sphinxConfig.mainnets = ["ethereum", "optimism", "polygon"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "polygon_mumbai"];
    }

    /// @notice Deploys the protocol.
    function run() public sphinx {
        // Set the manager, this can be changed and won't affect deployment addresses.
        MANAGER = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
        FEE_PROJECT_OWNER = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;

        // Deploy the protocol.
        deploy();
    }

    function deploy() public sphinx {
        address _safe = safeAddress();

        JBPermissions permissions = new JBPermissions();
        JBProjects projects = new JBProjects(_safe, _safe);
        JBDirectory directory = new JBDirectory(permissions, projects, _safe);
        JBSplits splits = new JBSplits(directory);
        JBRulesets rulesets = new JBRulesets(directory);
        directory.setIsAllowedToSetFirstController(
            address(
                new JBController({
                    permissions: permissions,
                    projects: projects,
                    directory: directory,
                    rulesets: rulesets,
                    tokens: new JBTokens(directory, new JBERC20()),
                    splits: splits,
                    fundAccessLimits: new JBFundAccessLimits(directory),
                    trustedForwarder: TRUSTED_FORWARDER
                })
            ),
            true
        );

        JBFeelessAddresses feeless = new JBFeelessAddresses(_safe);
        JBPrices prices = new JBPrices(permissions, projects, _safe);

        new JBMultiTerminal({
            permissions: permissions,
            projects: projects,
            directory: directory,
            splits: splits,
            store: new JBTerminalStore({directory: directory, rulesets: rulesets, prices: prices}),
            feelessAddresses: feeless,
            permit2: _PERMIT2,
            trustedForwarder: TRUSTED_FORWARDER
        });

        // If the manager is not the deployer we transfer all ownership to it.
        if (MANAGER != _safe && MANAGER != address(0)) {
            directory.transferOwnership(MANAGER);
            feeless.transferOwnership(MANAGER);
            prices.transferOwnership(MANAGER);
            projects.transferOwnership(MANAGER);
        }

        // Transfer ownership to the fee project owner.
        if (FEE_PROJECT_OWNER != _safe && FEE_PROJECT_OWNER != address(0)) {
            projects.safeTransferFrom(_safe, MANAGER, 1);
        }
    }
}
