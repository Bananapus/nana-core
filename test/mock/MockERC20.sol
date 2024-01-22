// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../helpers/TestBaseWorkflow.sol";

import {ERC20, IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 internal _decimals;

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
