// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/* 
Contract that deploys a target contract with other mock contracts to satisfy the constructor.
Tests relative to this contract will be dependent on mock calls/emits and stdStorage.
*/
contract JBPricesSetup is JBTest {
    address _owner = makeAddr("owner");

    // Mocks
    IJBPermissions public permissions = IJBPermissions(makeAddr("permissions"));
    IJBProjects public projects = IJBProjects(makeAddr("projects"));

    // Target Contract
    IJBPrices public _prices;

    function pricesSetup() public virtual {
        // Instantiate the contract being tested
        _prices = new JBPrices(permissions, projects, _owner);
    }
}
