// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

contract TestInitialProject_Local is JBTest {
    address _owner = makeAddr("owner");
    IJBProjects _projects;

    function setUp() public {}

    function test_WhenInitialOwnerDNEQZeroAddress() external {
        // It will create a project

        vm.expectEmit();
        emit IJBProjects.Create(1, _owner, address(this));
        _projects = new JBProjects(_owner, _owner);
    }
}
