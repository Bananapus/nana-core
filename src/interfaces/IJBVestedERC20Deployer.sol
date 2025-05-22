// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBDirectory} from "./IJBDirectory.sol";
import {IJBTokens} from "./IJBTokens.sol";
import {IJBToken} from "./IJBToken.sol";

interface IJBVestedERC20Deployer {
    event VestedERC20Deployed(address indexed token, uint256 indexed projectId, bytes32 salt);

    function DIRECTORY() external view returns (IJBDirectory);
    function TOKENS() external view returns (IJBTokens);
    function TOKEN() external view returns (address);

    /// @notice Deploys, initializes, and sets a JBVestedERC20 as the project's token.
    /// @param projectId The project ID.
    /// @param name The token's name.
    /// @param symbol The token's symbol.
    /// @param owner The token contract's owner.
    /// @param cliff The number of seconds to wait before the tokens start to unlock.
    /// @param unlockDuration The number of seconds it takes to unlock the full amount of tokens.
    /// @param salt The salt for deterministic deployment (optional, set to 0 for non-deterministic).
    /// @return token The address of the deployed and initialized JBVestedERC20.
    function deployVestedERC20ForProject(
        uint256 projectId,
        string calldata name,
        string calldata symbol,
        address owner,
        uint256 cliff,
        uint256 unlockDuration,
        bytes32 salt
    )
        external
        returns (IJBToken token);
}
