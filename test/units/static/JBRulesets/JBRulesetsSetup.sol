// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/* 
Contract that deploys a target contract with other mock contracts to satisfy the constructor.
Tests relative to this contract will be dependent on mock calls/emits and stdStorage.
*/
contract JBRulesetsSetup is JBTest {
    // Target Contract
    IJBRulesets public _rulesets;

    // Mocks
    IJBDirectory public directory = IJBDirectory(makeAddr("directory"));

    function rulesetsSetup() public virtual {
        // Instantiate the contract being tested
        _rulesets = new JBRulesets(directory);
    }
}
