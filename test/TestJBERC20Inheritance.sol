// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

import {ERC20Votes} from "../src/JBERC20.sol";

contract JBERC20Inheritance_Local is JBERC20, TestBaseWorkflow {
    /// This test is to verify that the inheritance order of JBERC20 is correct and that it calls the
    /// `ERC20Votes._update()`
    function test_votesUpdate() public {
        uint256 _max = _maxSupply();
        vm.expectRevert(abi.encodeWithSelector(ERC20Votes.ERC20ExceededSafeSupply.selector, _max + 1, _max));

        _update(address(0), address(100), _max + 1);
    }
}
