// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBDirectorySetup} from "./JBDirectorySetup.sol";

contract TestSetControllerOf_Local is JBDirectorySetup {
    using stdStorage for StdStorage;

    function setUp() public {
        super.directorySetup();
    }

    modifier givenProjectExists() {
        bytes memory _countCall = abi.encodeCall(IJBProjects.count, ());
        bytes memory _countReturn = abi.encode(type(uint256).max);

        mockExpect(address(projects), _countCall, _countReturn);
        _;
    }

    modifier whenCallerIsAllowedToSetFirstController() {
        stdstore.target(address(_directory)).sig("isAllowedToSetFirstController(address)").with_key(address(this)).depth(
            0
        ).checked_write(true);

        stdstore.target(address(_directory)).sig("controllerOf(uint256)").with_key(1).depth(0).checked_write(address(0));

        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(this));

        mockExpect(address(projects), _ownerOfCall, _ownerData);

        _;
    }

    modifier givenControllerIsAlreadySet() {
        address _bumController = makeAddr("bum");

        stdstore.target(address(_directory)).sig("controllerOf(uint256)").with_key(1).depth(0).checked_write(
            _bumController
        );

        // mock erc165 call
        bytes memory _supportCall =
            abi.encodeCall(IERC165.supportsInterface, (type(IJBDirectoryAccessControl).interfaceId));
        bytes memory _supportReturned = abi.encode(true);

        mockExpect(address(_bumController), _supportCall, _supportReturned);

        // mock access control call
        bytes memory _accessCall = abi.encodeCall(IJBDirectoryAccessControl.setControllerAllowed, (1));
        bytes memory _accessReturned = abi.encode(false);

        mockExpect(address(_bumController), _accessCall, _accessReturned);

        _;
    }

    function test_RevertWhenCallerDoesNotHaveAnyPermission() external {
        // it should revert
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(1));

        mockExpect(address(projects), _ownerOfCall, _ownerData);

        // mock first permissions call
        bytes memory _permissionsCall = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), address(1), 1, JBPermissionIds.SET_CONTROLLER, true, true)
        );
        bytes memory _permissionsReturned = abi.encode(false);

        mockExpect(address(permissions), _permissionsCall, _permissionsReturned);

        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        _directory.setControllerOf(1, IERC165(address(this)));
    }

    function test_RevertGivenAProjectDoesntExist() external whenCallerIsAllowedToSetFirstController {
        // it should revert

        // project count mock call
        bytes memory _countCall = abi.encodeCall(IJBProjects.count, ());
        bytes memory _countReturn = abi.encode(0);

        mockExpect(address(projects), _countCall, _countReturn);

        vm.expectRevert(abi.encodeWithSignature("INVALID_PROJECT_ID_IN_DIRECTORY()"));
        _directory.setControllerOf(1, IERC165(address(this)));
    }

    function test_RevertGivenCurrentControllerIsNotSetControllerAllowed()
        external
        whenCallerIsAllowedToSetFirstController
        givenProjectExists
        givenControllerIsAlreadySet
    {
        // it should revert
        vm.expectRevert(abi.encodeWithSignature("SET_CONTROLLER_NOT_ALLOWED()"));
        _directory.setControllerOf(1, IERC165(address(this)));
    }

    function test_GivenCurrentControllerIsSetControllerAllowed()
        external
        whenCallerIsAllowedToSetFirstController
        givenProjectExists
    {
        // it should set controllerOf and emit SetController
        vm.expectEmit();
        emit IJBDirectory.SetController(1, IERC165(address(this)), address(this));

        _directory.setControllerOf(1, IERC165(address(this)));
    }

    function test_GivenCurrentControllerIsSetAndMigrating() external givenProjectExists {
        address _bumController = makeAddr("bum");

        stdstore.target(address(_directory)).sig("controllerOf(uint256)").with_key(1).depth(0).checked_write(
            _bumController
        );

        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(this));

        mockExpect(address(projects), _ownerOfCall, _ownerData);

        // Mock call to bum controller setControllerAllowed
        mockExpect(
            _bumController, abi.encodeCall(IJBDirectoryAccessControl.setControllerAllowed, (1)), abi.encode(true)
        );

        // Mock call to it's interface support
        mockExpect(
            _bumController,
            abi.encodeCall(IERC165.supportsInterface, (type(IJBDirectoryAccessControl).interfaceId)),
            abi.encode(true)
        );
        mockExpect(
            _bumController,
            abi.encodeCall(IERC165.supportsInterface, (type(IJBMigratable).interfaceId)),
            abi.encode(true)
        );

        // it should set controllerOf and emit SetController
        vm.expectEmit();
        emit IJBDirectory.SetController(1, IERC165(address(this)), address(this));

        _directory.setControllerOf(1, IERC165(address(this)));
    }
}
