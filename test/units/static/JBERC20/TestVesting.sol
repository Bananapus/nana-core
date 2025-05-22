// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {JBVestedERC20} from "../../../../src/JBVestedERC20.sol";

contract TestVesting is JBTest {
    address internal _owner = makeAddr("owner");
    address internal _user = makeAddr("user");
    JBVestedERC20 internal _vestedToken;

    string internal _name = "VestedToken";
    string internal _symbol = "VST";
    uint256 internal _projectId = 1;
    uint256 internal _cliff = 1 days;
    uint256 internal _duration = 3 days;
    uint256 internal _amount = 1000 ether;

    function setUp() public {
        _vestedToken = new JBVestedERC20();
        _vestedToken.initialize(_name, _symbol, _owner, _projectId, _cliff, _duration);
        vm.startPrank(_owner);
        _vestedToken.mint(_user, _amount);
        vm.stopPrank();
    }

    function test_BalanceAndVesting_BeforeCliff() public {
        // Before cliff, nothing is vested
        assertEq(_vestedToken.balanceOf(_user), 0);
        assertEq(_vestedToken.vestingAmount(_user), _amount);
        assertEq(_vestedToken.vestedAmount(_user), 0);
    }

    function test_BalanceAndVesting_DuringVesting() public {
        // Move time to halfway through vesting (after cliff)
        vm.warp(block.timestamp + _cliff + _duration / 2);
        uint256 expectedVested = (_amount * (_duration / 2 + _cliff)) / _duration;
        uint256 actualVested = _vestedToken.balanceOf(_user);
        assertGt(actualVested, 0);
        assertLt(actualVested, _amount);
        assertEq(_vestedToken.vestingAmount(_user) + actualVested, _amount);
    }

    function test_BalanceAndVesting_AfterFullVesting() public {
        // Move time past full vesting
        vm.warp(block.timestamp + _cliff + _duration + 1);
        assertEq(_vestedToken.balanceOf(_user), _amount);
        assertEq(_vestedToken.vestingAmount(_user), 0);
        assertEq(_vestedToken.vestedAmount(_user), _amount);
    }

    function test_Transfer_RevertIfNotVested() public {
        // Try to transfer before cliff
        vm.startPrank(_user);
        vm.expectRevert();
        _vestedToken.transfer(makeAddr("recipient"), 1 ether);
        vm.stopPrank();
    }

    function test_Transfer_SucceedIfVested() public {
        // Move time past full vesting
        vm.warp(block.timestamp + _cliff + _duration + 1);
        vm.startPrank(_user);
        _vestedToken.transfer(makeAddr("recipient"), _amount);
        vm.stopPrank();
    }

    function test_CleanupFullyVestedSchedules() public {
        // Move time past full vesting
        vm.warp(block.timestamp + _cliff + _duration + 1);
        // Transfer triggers cleanup
        vm.startPrank(_user);
        _vestedToken.transfer(makeAddr("recipient"), 1 ether);
        vm.stopPrank();
        // The vesting schedule array should be empty
        // (Direct storage access for test purposes)
        bytes32 slot = keccak256(abi.encode(_user, uint256(6))); // _vestingSchedules is at storage slot 6
        uint256 len;
        assembly { len := sload(slot) }
        assertEq(len, 0);
    }
} 