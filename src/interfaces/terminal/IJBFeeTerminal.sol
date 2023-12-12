// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBTerminal} from "./IJBTerminal.sol";
import {JBFee} from "../../structs/JBFee.sol";

/// @notice A terminal that can process and hold fees.
interface IJBFeeTerminal is IJBTerminal {
    event HoldFee(
        uint256 indexed projectId,
        address indexed token,
        uint256 indexed amount,
        uint256 fee,
        address beneficiary,
        address caller
    );

    event ProcessFee(
        uint256 indexed projectId,
        address indexed token,
        uint256 indexed amount,
        bool wasHeld,
        address beneficiary,
        address caller
    );

    event UnlockHeldFees(
        uint256 indexed projectId,
        address indexed token,
        uint256 indexed amount,
        uint256 unlockedFees,
        uint256 leftoverAmount,
        address caller
    );
    event SetFeelessAddress(address indexed account, bool indexed isFeeless, address caller);

    event FeeReverted(
        uint256 indexed projectId,
        address indexed token,
        uint256 indexed feeProjectId,
        uint256 amount,
        bytes reason,
        address caller
    );

    function FEE() external view returns (uint256);

    function heldFeesOf(uint256 projectId, address token) external view returns (JBFee[] memory);

    function isFeelessAddress(address account) external view returns (bool);

    function processHeldFeesOf(uint256 projectId, address token) external;

    function setFeelessAddress(address account, bool flag) external;
}
