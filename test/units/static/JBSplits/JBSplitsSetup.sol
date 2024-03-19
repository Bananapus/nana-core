// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/* 
Contract that deploys a target contract with other mock contracts to satisfy the constructor.
Tests relative to this contract will be dependent on mock calls/emits and stdStorage.
*/
contract JBSplitsSetup is JBTest {
    address _owner = makeAddr("owner");

    // Mocks
    IJBDirectory public directory = IJBDirectory(makeAddr("directory"));

    // Target Contract
    IJBSplits public _splits;

    function splitsSetup() public virtual {
        // Instantiate the contract being tested
        _splits = new JBSplits(directory);
    }
}
