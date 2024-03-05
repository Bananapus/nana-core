// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@sphinx-labs/contracts/SphinxPlugin.sol";

import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {JBPermissions} from "src/JBPermissions.sol";
import {JBProjects} from "src/JBProjects.sol";
import {JBPrices} from "src/JBPrices.sol";
import {JBRulesets} from "src/JBRulesets.sol";
import {JBDirectory} from "src/JBDirectory.sol";
import {JBTokens} from "src/JBTokens.sol";
import {JBSplits} from "src/JBSplits.sol";
import {JBFeelessAddresses} from "src/JBFeelessAddresses.sol";
import {JBFundAccessLimits} from "src/JBFundAccessLimits.sol";
import {JBController} from "src/JBController.sol";
import {JBTerminalStore} from "src/JBTerminalStore.sol";
import {JBMultiTerminal} from "src/JBMultiTerminal.sol";

contract Deploy is Sphinx {
    /// @notice The universal PERMIT2 address.
    IPermit2 private constant _PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    /// @notice The address that is allowed to forward calls to the terminal and controller on a users behalf.
    address private constant TRUSTED_FORWARDER = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    /// @notice The address that will manage the few privileged functions of the protocol.
    address private constant MANAGER = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;

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
        if (
            block.chainid != 1 && block.chainid != 11_155_111 && block.chainid != 420 && block.chainid != 11_155_420
                && block.chainid != 137 && block.chainid != 80_001
        ) {
            revert("Invalid RPC / no juice contracts deployed on this network");
        }

        address _sender = safeAddress();

        JBPermissions permissions = new JBPermissions();
        JBProjects projects = new JBProjects(MANAGER);
        JBDirectory directory = new JBDirectory(permissions, projects, _sender);
        JBSplits splits = new JBSplits(directory);
        JBRulesets rulesets = new JBRulesets(directory);
        directory.setIsAllowedToSetFirstController(
            address(
                new JBController({
                    permissions: permissions,
                    projects: projects,
                    directory: directory,
                    rulesets: rulesets,
                    tokens: new JBTokens(directory),
                    splits: splits,
                    fundAccessLimits: new JBFundAccessLimits(directory),
                    trustedForwarder: TRUSTED_FORWARDER
                })
            ),
            true
        );
        directory.transferOwnership(MANAGER);
        new JBMultiTerminal({
            permissions: permissions,
            projects: projects,
            directory: directory,
            splits: splits,
            store: new JBTerminalStore({
                directory: directory,
                rulesets: rulesets,
                prices: new JBPrices(permissions, projects, MANAGER)
            }),
            feelessAddresses: new JBFeelessAddresses(MANAGER),
            permit2: _PERMIT2,
            trustedForwarder: TRUSTED_FORWARDER
        });
    }
}
