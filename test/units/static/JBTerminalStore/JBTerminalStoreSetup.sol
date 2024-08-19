// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/* 
Contract that deploys a target contract with other mock contracts to satisfy the constructor.
Tests relative to this contract will be dependent on mock calls/emits and stdStorage.
*/
contract JBTerminalStoreSetup is JBTest {
    // Mocks
    IJBDirectory public directory = IJBDirectory(makeAddr("directory"));
    IJBRulesets public rulesets = IJBRulesets(makeAddr("rules"));
    IJBPrices public prices = IJBPrices(makeAddr("prices"));

    // Target Contract
    IJBTerminalStore public _store;

    function terminalStoreSetup() public virtual {
        // Instantiate the contract being tested
        _store = new JBTerminalStore(directory, prices, rulesets);
    }
}
