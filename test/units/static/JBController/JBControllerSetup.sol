// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/* 
Contract that deploys a target contract with other mock contracts to satisfy the constructor.
Tests relative to this contract will be dependent on mock calls/emits and stdStorage.
*/
contract JBControllerSetup is JBTest {
    // Target Contract
    IJBController public _controller;

    // Mocks
    IJBPermissions public permissions = IJBPermissions(makeAddr("permissions"));
    IJBProjects public projects = IJBProjects(makeAddr("projects"));
    IJBDirectory public directory = IJBDirectory(makeAddr("directory"));
    IJBRulesets public rulesets = IJBRulesets(makeAddr("rulesets"));
    IJBTokens public tokens = IJBTokens(makeAddr("tokens"));
    IJBPrices public prices = IJBPrices(makeAddr("prices"));
    IJBSplits public splits = IJBSplits(makeAddr("splits"));
    IJBFundAccessLimits public fundAccessLimits = IJBFundAccessLimits(makeAddr("limits"));
    address public trustedForwarder = makeAddr("forwarder");

    function controllerSetup() public virtual {
        // Instantiate the contract being tested
        _controller = new JBController(
            permissions, projects, directory, rulesets, tokens, splits, fundAccessLimits, prices, trustedForwarder
        );
    }
}
