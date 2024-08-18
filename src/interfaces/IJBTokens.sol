// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBToken} from "./IJBToken.sol";

interface IJBTokens {
    event DeployERC20(
        uint256 indexed projectId, IJBToken indexed token, string name, string symbol, bytes32 salt, address caller
    );
    event Burn(
        address indexed holder,
        uint256 indexed projectId,
        uint256 amount,
        uint256 initialCreditBalance,
        uint256 initialTokenBalance,
        address caller
    );
    event ClaimTokens(
        address indexed holder,
        uint256 indexed projectId,
        uint256 initialCreditBalance,
        uint256 amount,
        address beneficiary,
        address caller
    );
    event Mint(
        address indexed holder, uint256 indexed projectId, uint256 amount, bool tokensWereClaimed, address caller
    );
    event SetToken(uint256 indexed projectId, IJBToken indexed newToken, address caller);
    event TransferCredits(
        address indexed holder, uint256 indexed projectId, address indexed recipient, uint256 amount, address caller
    );

    function creditBalanceOf(address holder, uint256 projectId) external view returns (uint256);
    function projectIdOf(IJBToken token) external view returns (uint256);
    function tokenOf(uint256 projectId) external view returns (IJBToken);
    function totalCreditSupplyOf(uint256 projectId) external view returns (uint256);

    function totalBalanceOf(address holder, uint256 projectId) external view returns (uint256 result);
    function totalSupplyOf(uint256 projectId) external view returns (uint256);

    function burnFrom(address holder, uint256 projectId, uint256 amount) external;
    function claimTokensFor(address holder, uint256 projectId, uint256 amount, address beneficiary) external;
    function deployERC20For(
        uint256 projectId,
        string calldata name,
        string calldata symbol,
        bytes32 salt
    )
        external
        returns (IJBToken token);
    function mintFor(address holder, uint256 projectId, uint256 amount) external;
    function setTokenFor(uint256 projectId, IJBToken token) external;
    function transferCreditsFrom(address holder, uint256 projectId, address recipient, uint256 amount) external;
}
