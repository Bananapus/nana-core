// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBVestedERC20} from "./JBVestedERC20.sol";
import {IJBTokens} from "./interfaces/IJBTokens.sol";
import {IJBController} from "./interfaces/IJBController.sol";
import {IJBToken} from "./interfaces/IJBToken.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";

contract JBVestedERC20Deployer {
    IJBTokens public immutable TOKENS;
    IJBDirectory public immutable DIRECTORY;
    address public immutable TOKEN;

    event VestedERC20Deployed(address indexed token, uint256 indexed projectId, bytes32 salt);

    /// @param directory A contract storing directories of terminals and controllers for each project.
    /// @param tokens A contract that manages token minting and burning.
    /// @param token The JBVestedERC20 implementation.
    constructor(IJBDirectory directory, IJBTokens tokens, address token) {
        DIRECTORY = directory;
        TOKENS = tokens;
        TOKEN = token;
    }

    /// @notice Deploys, initializes, and sets a JBVestedERC20 as the project's token.
    /// @param projectId The project ID.
    /// @param name The token's name.
    /// @param symbol The token's symbol.
    /// @param cliff The number of seconds to wait before the tokens start to unlock.
    /// @param unlockDuration The number of seconds it takes to unlock the full amount of tokens.
    /// @param vestingAdmin The admin address for managing vesting exemptions.
    /// @param salt The salt for deterministic deployment (optional, set to 0 for non-deterministic).
    /// @return token The address of the deployed and initialized JBVestedERC20.
    function deployVestedERC20ForProject(
        uint256 projectId,
        string memory name,
        string memory symbol,
        uint256 cliff,
        uint256 unlockDuration,
        address vestingAdmin,
        bytes32 salt
    )
        external
        returns (JBVestedERC20 token)
    {
        token = salt == bytes32(0)
            ? IJBToken(Clones.clone(address(TOKEN)))
            : IJBToken(Clones.cloneDeterministic(address(TOKEN), keccak256(abi.encode(msg.sender, salt))));
        token.initialize({
            name: name,
            symbol: symbol,
            owner: address(TOKENS),
            projectId: projectId,
            cliff: cliff,
            unlockDuration: unlockDuration,
            vestingAdmin: admin
        });
        // Get the controller for the project from the directory
        IJBController controller = IJBController(address(DIRECTORY.controllerOf(projectId)));
        controller.setTokenFor({projectId: projectId, token: IJBToken(address(token))});
        emit VestedERC20Deployed(address(token), projectId, salt);
    }
}
