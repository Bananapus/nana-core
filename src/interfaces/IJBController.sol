// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IJBDirectory} from "./IJBDirectory.sol";
import {IJBDirectoryAccessControl} from "./IJBDirectoryAccessControl.sol";
import {IJBFundAccessLimits} from "./IJBFundAccessLimits.sol";
import {IJBPriceFeed} from "./IJBPriceFeed.sol";
import {IJBPrices} from "./IJBPrices.sol";
import {IJBProjects} from "./IJBProjects.sol";
import {IJBProjectUriRegistry} from "./IJBProjectUriRegistry.sol";
import {IJBRulesets} from "./IJBRulesets.sol";
import {IJBSplits} from "./IJBSplits.sol";
import {IJBTerminal} from "./IJBTerminal.sol";
import {IJBToken} from "./IJBToken.sol";
import {IJBTokens} from "./IJBTokens.sol";
import {JBApprovalStatus} from "./../enums/JBApprovalStatus.sol";
import {JBRuleset} from "./../structs/JBRuleset.sol";
import {JBRulesetConfig} from "./../structs/JBRulesetConfig.sol";
import {JBRulesetMetadata} from "./../structs/JBRulesetMetadata.sol";
import {JBRulesetWithMetadata} from "./../structs/JBRulesetWithMetadata.sol";
import {JBSplit} from "./../structs/JBSplit.sol";
import {JBSplitGroup} from "./../structs/JBSplitGroup.sol";
import {JBTerminalConfig} from "./../structs/JBTerminalConfig.sol";

interface IJBController is IERC165, IJBProjectUriRegistry, IJBDirectoryAccessControl {
    event BurnTokens(
        address indexed holder, uint256 indexed projectId, uint256 tokenCount, string memo, address caller
    );
    event LaunchProject(uint256 rulesetId, uint256 projectId, string projectUri, string memo, address caller);
    event LaunchRulesets(uint256 rulesetId, uint256 projectId, string memo, address caller);
    event MintTokens(
        address indexed beneficiary,
        uint256 indexed projectId,
        uint256 tokenCount,
        uint256 beneficiaryTokenCount,
        string memo,
        uint256 reservedPercent,
        address caller
    );
    event PrepMigration(uint256 indexed projectId, address from, address caller);
    event QueueRulesets(uint256 rulesetId, uint256 projectId, string memo, address caller);
    event ReservedDistributionReverted(
        uint256 indexed projectId, JBSplit split, uint256 tokenCount, bytes reason, address caller
    );
    event SendReservedTokensToSplit(
        uint256 indexed projectId,
        uint256 indexed rulesetId,
        uint256 indexed groupId,
        JBSplit split,
        uint256 tokenCount,
        address caller
    );
    event SendReservedTokensToSplits(
        uint256 indexed rulesetId,
        uint256 indexed rulesetCycleNumber,
        uint256 indexed projectId,
        address owner,
        uint256 tokenCount,
        uint256 leftoverAmount,
        address caller
    );
    event SetUri(uint256 indexed projectId, string uri, address caller);

    function DIRECTORY() external view returns (IJBDirectory);
    function FUND_ACCESS_LIMITS() external view returns (IJBFundAccessLimits);
    function PRICES() external view returns (IJBPrices);
    function PROJECTS() external view returns (IJBProjects);
    function RULESETS() external view returns (IJBRulesets);
    function SPLITS() external view returns (IJBSplits);
    function TOKENS() external view returns (IJBTokens);

    function allRulesetsOf(
        uint256 projectId,
        uint256 startingId,
        uint256 size
    )
        external
        view
        returns (JBRulesetWithMetadata[] memory rulesets);
    function currentRulesetOf(uint256 projectId)
        external
        view
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);
    function getRulesetOf(
        uint256 projectId,
        uint256 rulesetId
    )
        external
        view
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);
    function latestQueuedRulesetOf(uint256 projectId)
        external
        view
        returns (JBRuleset memory, JBRulesetMetadata memory metadata, JBApprovalStatus);
    function pendingReservedTokenBalanceOf(uint256 projectId) external view returns (uint256);
    function totalTokenSupplyWithReservedTokensOf(uint256 projectId) external view returns (uint256);
    function upcomingRulesetOf(uint256 projectId)
        external
        view
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);

    function addPriceFeed(
        uint256 projectId,
        uint256 pricingCurrency,
        uint256 unitCurrency,
        IJBPriceFeed feed
    )
        external;
    function burnTokensOf(address holder, uint256 projectId, uint256 tokenCount, string calldata memo) external;
    function claimTokensFor(address holder, uint256 projectId, uint256 tokenCount, address beneficiary) external;
    function deployERC20For(
        uint256 projectId,
        string calldata name,
        string calldata symbol,
        bytes32 salt
    )
        external
        returns (IJBToken token);
    function launchProjectFor(
        address owner,
        string calldata projectUri,
        JBRulesetConfig[] calldata rulesetConfigurations,
        JBTerminalConfig[] memory terminalConfigurations,
        string calldata memo
    )
        external
        returns (uint256 projectId);
    function launchRulesetsFor(
        uint256 projectId,
        JBRulesetConfig[] calldata rulesetConfigurations,
        JBTerminalConfig[] memory terminalConfigurations,
        string calldata memo
    )
        external
        returns (uint256 rulesetId);
    function mintTokensOf(
        uint256 projectId,
        uint256 tokenCount,
        address beneficiary,
        string calldata memo,
        bool useReservedPercent
    )
        external
        returns (uint256 beneficiaryTokenCount);
    function queueRulesetsOf(
        uint256 projectId,
        JBRulesetConfig[] calldata rulesetConfigurations,
        string calldata memo
    )
        external
        returns (uint256 rulesetId);
    function sendReservedTokensToSplitsOf(uint256 projectId) external returns (uint256);
    function setSplitGroupsOf(uint256 projectId, uint256 rulesetId, JBSplitGroup[] calldata splitGroups) external;
    function setTokenFor(uint256 projectId, IJBToken token) external;
    function transferCreditsFrom(address holder, uint256 projectId, address recipient, uint256 creditCount) external;
}
