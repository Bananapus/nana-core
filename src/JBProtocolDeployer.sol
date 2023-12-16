// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPermit2} from "lib/permit2/src/interfaces/IPermit2.sol";
import "./JBPermissions.sol";
import "./JBProjects.sol";
import "./JBPrices.sol";
import "./JBRulesets.sol";
import "./JBDirectory.sol";
import "./JBTokens.sol";
import "./JBSplits.sol";
import "./JBFeelessAddresses.sol";
import "./JBFundAccessLimits.sol";
import "./JBController.sol";
import "./JBTerminalStore.sol";
import "./JBMultiTerminal.sol";

// Deploys the protocol.
contract JBProtocolDeployer {
    /// @notice The universal PERMIT2 address.
    IPermit2 internal constant _PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    constructor() {}

    /// @notice Deploys the protocol.
    /// @param manager The address that will manage the few privileged functions of the protocol.
    /// @param trustedForwarder The address that is allowed to forward calls to the terminal and controller on a payer's
    /// behalf.
    function deployJBProtocol(address manager, address trustedForwarder) external {
        JBPermissions permissions = new JBPermissions();
        JBProjects projects = new JBProjects(manager);
        JBDirectory directory = new JBDirectory(permissions, projects, msg.sender);
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
                    trustedForwarder: trustedForwarder
                })
            ),
            true
        );
        directory.transferOwnership(manager);
        new JBMultiTerminal({
            permissions: permissions,
            projects: projects,
            directory: directory,
            splits: splits,
            store: new JBTerminalStore({
                directory: directory,
                rulesets: rulesets,
                prices: new JBPrices(permissions, projects, manager)
            }),
            feelessAddresses: new JBFeelessAddresses(manager),
            permit2: _PERMIT2,
            trustedForwarder: trustedForwarder
        });
    }
}
