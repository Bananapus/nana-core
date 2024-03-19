// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/* 
Contract that deploys a target contract with other mock contracts to satisfy the constructor.
Tests relative to this contract will be dependent on mock calls/emits and stdStorage.
*/
contract JBFeelessSetup is JBTest {
    address _owner = makeAddr("owner");

    // Target Contract
    IJBFeelessAddresses public _feelessAddresses;

    function feelessAddressesSetup() public virtual {
        // Instantiate the contract being tested
        _feelessAddresses = new JBFeelessAddresses(_owner);
    }
}
