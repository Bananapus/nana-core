// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBRulesets} from "./IJBRulesets.sol";
import {IJBProjects} from "./IJBProjects.sol";
import {IJBToken} from "./IJBToken.sol";
import {IJBControlled} from "./IJBControlled.sol";

interface IJBTokens is IJBControlled {
    event DeployERC20(uint256 indexed projectId, IJBToken indexed token, string name, string symbol, address caller);

    event Mint(
        address indexed holder, uint256 indexed projectId, uint256 amount, bool tokensWereClaimed, address caller
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

    event SetToken(uint256 indexed projectId, IJBToken indexed newToken, address caller);

    event TransferCredits(
        address indexed holder, uint256 indexed projectId, address indexed recipient, uint256 amount, address caller
    );

    function tokenOf(uint32 projectId) external view returns (IJBToken);

    function projectIdOf(IJBToken token) external view returns (uint256);

    function creditBalanceOf(address holder, uint32 projectId) external view returns (uint256);

    function totalCreditSupplyOf(uint32 projectId) external view returns (uint256);

    function totalSupplyOf(uint32 projectId) external view returns (uint256);

    function totalBalanceOf(address holder, uint32 projectId) external view returns (uint256 result);

    function deployERC20For(
        uint32 projectId,
        string calldata name,
        string calldata symbol
    )
        external
        returns (IJBToken token);

    function setTokenFor(uint32 projectId, IJBToken token) external;

    function burnFrom(address holder, uint32 projectId, uint256 amount) external;

    function mintFor(address holder, uint32 projectId, uint256 amount) external;

    function claimTokensFor(address holder, uint32 projectId, uint256 amount, address beneficiary) external;

    function transferCreditsFrom(address holder, uint32 projectId, address recipient, uint256 amount) external;
}
