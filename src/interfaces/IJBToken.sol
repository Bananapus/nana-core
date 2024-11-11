// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IJBToken {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function projectId() external view returns (uint256);
    function totalSupply() external view returns (uint256);

    function initialize(string memory name, string memory symbol, uint256 projectId, address owner) external;
    function burn(address account, uint256 amount) external;
    function mint(address account, uint256 amount) external;
}
