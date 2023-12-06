// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBTerminal} from "./IJBTerminal.sol";
import {IJBRedeemHook} from "../IJBRedeemHook.sol";
import {JBDidRedeemData} from "../../structs/JBDidRedeemData.sol";

/// @notice A terminal that can be redeemed from.
interface IJBRedeemTerminal is IJBTerminal {
    event RedeemTokens(
        uint256 indexed rulesetId,
        uint256 indexed rulesetCycleNumber,
        uint256 indexed projectId,
        address holder,
        address beneficiary,
        uint256 tokenCount,
        uint256 reclaimedAmount,
        bytes metadata,
        address caller
    );

    event HookDidRedeem(
        IJBRedeemHook indexed hook,
        JBDidRedeemData data,
        uint256 payloadAmount,
        uint256 fee,
        address caller
    );

    function redeemTokensOf(
        address holder,
        uint256 projectId,
        address token,
        uint256 count,
        uint256 minReclaimed,
        address payable beneficiary,
        bytes calldata metadata
    ) external returns (uint256 reclaimAmount);
}
