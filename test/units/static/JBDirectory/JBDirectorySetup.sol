// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/* 
Contract that deploys a target contract with other mock contracts to satisfy the constructor.
Tests relative to this contract will be dependent on mock calls/emits and stdStorage.
*/
contract JBDirectorySetup is JBTest {
    // Target Contract
    IJBDirectory public _directory;

    // Mocks
    IJBPermissions public permissions = IJBPermissions(makeAddr("permissions"));
    IJBProjects public projects = IJBProjects(makeAddr("projects"));

    function directorySetup() public virtual {
        // Instantiate the contract being tested
        _directory = new JBDirectory(permissions, projects, makeAddr("Juicer"));
    }
}
