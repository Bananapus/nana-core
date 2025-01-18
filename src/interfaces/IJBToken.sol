// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IJBToken {
    function balanceOf(address account) external view returns (uint256);
    function canBeAddedTo(uint256 projectId) external view returns (bool);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);

    function initialize(string memory name, string memory symbol, address owner) external;
    function burn(address account, uint256 amount) external;
    function mint(address account, uint256 amount) external;
}
