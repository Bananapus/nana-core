/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Context, ERC165, ERC2771Context, IERC165, IJBController, IJBDirectory, IJBDirectoryAccessControl, IJBFundAccessLimits, IJBMigratable, IJBPermissioned, IJBPermissions, IJBProjectMetadataRegistry, IJBProjects, IJBRulesets, IJBSplitHook, IJBSplits, IJBTerminal, IJBToken, IJBTokens, JBApprovalStatus, JBConstants, JBController, JBPermissionIds, JBPermissioned, JBRuleset, JBRulesetConfig, JBRulesetMetadata, JBRulesetMetadataResolver, JBSplit, JBSplitGroup, JBSplitGroupIds, JBSplitHookContext, JBTerminalConfig, mulDiv} from 'src/JBController.sol';
import {Context} from 'lib/openzeppelin-contracts/contracts/utils/Context.sol';
import {ERC165} from 'lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol';
import {IERC165} from 'lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol';
import {ERC2771Context} from 'lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol';
import {mulDiv} from 'lib/prb-math/src/Common.sol';
import {JBPermissioned} from 'src/abstract/JBPermissioned.sol';
import {JBApprovalStatus} from 'src/enums/JBApprovalStatus.sol';
import {IJBController} from 'src/interfaces/IJBController.sol';
import {IJBDirectory} from 'src/interfaces/IJBDirectory.sol';
import {IJBFundAccessLimits} from 'src/interfaces/IJBFundAccessLimits.sol';
import {IJBRulesets} from 'src/interfaces/IJBRulesets.sol';
import {IJBDirectoryAccessControl} from 'src/interfaces/IJBDirectoryAccessControl.sol';
import {IJBMigratable} from 'src/interfaces/IJBMigratable.sol';
import {IJBPermissioned} from 'src/interfaces/IJBPermissioned.sol';
import {IJBPermissions} from 'src/interfaces/IJBPermissions.sol';
import {IJBTerminal} from 'src/interfaces/terminal/IJBTerminal.sol';
import {IJBProjects} from 'src/interfaces/IJBProjects.sol';
import {IJBProjectMetadataRegistry} from 'src/interfaces/IJBProjectMetadataRegistry.sol';
import {IJBSplitHook} from 'src/interfaces/IJBSplitHook.sol';
import {IJBSplits} from 'src/interfaces/IJBSplits.sol';
import {IJBToken} from 'src/interfaces/IJBToken.sol';
import {IJBTokens} from 'src/interfaces/IJBTokens.sol';
import {JBConstants} from 'src/libraries/JBConstants.sol';
import {JBRulesetMetadataResolver} from 'src/libraries/JBRulesetMetadataResolver.sol';
import {JBPermissionIds} from 'src/libraries/JBPermissionIds.sol';
import {JBSplitGroupIds} from 'src/libraries/JBSplitGroupIds.sol';
import {JBRuleset} from 'src/structs/JBRuleset.sol';
import {JBRulesetConfig} from 'src/structs/JBRulesetConfig.sol';
import {JBRulesetMetadata} from 'src/structs/JBRulesetMetadata.sol';
import {JBTerminalConfig} from 'src/structs/JBTerminalConfig.sol';
import {JBSplit} from 'src/structs/JBSplit.sol';
import {JBSplitGroup} from 'src/structs/JBSplitGroup.sol';
import {JBSplitHookContext} from 'src/structs/JBSplitHookContext.sol';

contract MockJBController is JBController, Test {

  constructor(IJBPermissions permissions, IJBProjects projects, IJBDirectory directory, IJBRulesets rulesets, IJBTokens tokens, IJBSplits splits, IJBFundAccessLimits fundAccessLimits, address trustedForwarder) JBController(permissions, projects, directory, rulesets, tokens, splits, fundAccessLimits, trustedForwarder) {}
  /// Mocked State Variables
  function set_pendingReservedTokenBalanceOf(uint256 _key0, uint256 _value) public {
    pendingReservedTokenBalanceOf[_key0] = _value;
  }
  
  function mock_call_pendingReservedTokenBalanceOf(uint256 _key0, uint256 _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("pendingReservedTokenBalanceOf(uint256)", _key0),
      abi.encode(_value)
    );
  }
  
  function set_metadataOf(uint256 _key0, string memory _value) public {
    metadataOf[_key0] = _value;
  }
  
  function mock_call_metadataOf(uint256 _key0, string memory _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("metadataOf(uint256)", _key0),
      abi.encode(_value)
    );
  }
  
  /// Mocked External Functions
  function mock_call_totalTokenSupplyWithReservedTokensOf(uint256 projectId, uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("totalTokenSupplyWithReservedTokensOf(uint256)", projectId),
      abi.encode(_return0)
    );
  }
  
  function mock_call_getRulesetOf(uint256 projectId, uint256 rulesetId, JBRuleset memory ruleset, JBRulesetMetadata memory metadata) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("getRulesetOf(uint256,uint256)", projectId, rulesetId),
      abi.encode(ruleset, metadata)
    );
  }
  
  function mock_call_latestQueuedRulesetOf(uint256 projectId, JBRuleset memory ruleset, JBRulesetMetadata memory metadata, JBApprovalStatus approvalStatus) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("latestQueuedRulesetOf(uint256)", projectId),
      abi.encode(ruleset, metadata, approvalStatus)
    );
  }
  
  function mock_call_currentRulesetOf(uint256 projectId, JBRuleset memory ruleset, JBRulesetMetadata memory metadata) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("currentRulesetOf(uint256)", projectId),
      abi.encode(ruleset, metadata)
    );
  }
  
  function mock_call_queuedRulesetOf(uint256 projectId, JBRuleset memory ruleset, JBRulesetMetadata memory metadata) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("queuedRulesetOf(uint256)", projectId),
      abi.encode(ruleset, metadata)
    );
  }
  
  function mock_call_setTerminalsAllowed(uint256 projectId, bool _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setTerminalsAllowed(uint256)", projectId),
      abi.encode(_return0)
    );
  }
  
  function mock_call_setControllerAllowed(uint256 projectId, bool _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setControllerAllowed(uint256)", projectId),
      abi.encode(_return0)
    );
  }
  
  function mock_call_supportsInterface(bytes4 interfaceId, bool _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("supportsInterface(bytes4)", interfaceId),
      abi.encode(_return0)
    );
  }
  
  function mock_call_launchProjectFor(address owner, string calldata projectMetadata, JBRulesetConfig[] calldata rulesetConfigurations, JBTerminalConfig[] calldata terminalConfigurations, string memory memo, uint256 projectId) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("launchProjectFor(address,string,JBRulesetConfig[],JBTerminalConfig[],string)", owner, projectMetadata, rulesetConfigurations, terminalConfigurations, memo),
      abi.encode(projectId)
    );
  }
  
  function mock_call_launchRulesetsFor(uint256 projectId, JBRulesetConfig[] calldata rulesetConfigurations, JBTerminalConfig[] calldata terminalConfigurations, string memory memo, uint256 rulesetId) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("launchRulesetsFor(uint256,JBRulesetConfig[],JBTerminalConfig[],string)", projectId, rulesetConfigurations, terminalConfigurations, memo),
      abi.encode(rulesetId)
    );
  }
  
  function mock_call_queueRulesetsOf(uint256 projectId, JBRulesetConfig[] calldata rulesetConfigurations, string calldata memo, uint256 rulesetId) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("queueRulesetsOf(uint256,JBRulesetConfig[],string)", projectId, rulesetConfigurations, memo),
      abi.encode(rulesetId)
    );
  }
  
  function mock_call_mintTokensOf(uint256 projectId, uint256 tokenCount, address beneficiary, string calldata memo, bool useReservedRate, uint256 beneficiaryTokenCount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("mintTokensOf(uint256,uint256,address,string,bool)", projectId, tokenCount, beneficiary, memo, useReservedRate),
      abi.encode(beneficiaryTokenCount)
    );
  }
  
  function mock_call_burnTokensOf(address holder, uint256 projectId, uint256 tokenCount, string calldata memo) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("burnTokensOf(address,uint256,uint256,string)", holder, projectId, tokenCount, memo),
      abi.encode()
    );
  }
  
  function mock_call_sendReservedTokensToSplitsOf(uint256 projectId, string calldata memo, uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("sendReservedTokensToSplitsOf(uint256,string)", projectId, memo),
      abi.encode(_return0)
    );
  }
  
  function mock_call_receiveMigrationFrom(IERC165 from, uint256 projectId) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("receiveMigrationFrom(IERC165,uint256)", from, projectId),
      abi.encode()
    );
  }
  
  function mock_call_migrateController(uint256 projectId, IJBMigratable to) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("migrateController(uint256,IJBMigratable)", projectId, to),
      abi.encode()
    );
  }
  
  function mock_call_setMetadataOf(uint256 projectId, string calldata metadata) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setMetadataOf(uint256,string)", projectId, metadata),
      abi.encode()
    );
  }
  
  function mock_call_setSplitGroupsOf(uint256 projectId, uint256 rulesetId, JBSplitGroup[] calldata splitGroups) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setSplitGroupsOf(uint256,uint256,JBSplitGroup[])", projectId, rulesetId, splitGroups),
      abi.encode()
    );
  }
  
  function mock_call_deployERC20For(uint256 projectId, string calldata name, string calldata symbol, IJBToken token) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("deployERC20For(uint256,string,string)", projectId, name, symbol),
      abi.encode(token)
    );
  }
  
  function mock_call_setTokenFor(uint256 projectId, IJBToken token) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setTokenFor(uint256,IJBToken)", projectId, token),
      abi.encode()
    );
  }
  
  function mock_call_claimTokensFor(address holder, uint256 projectId, uint256 amount, address beneficiary) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("claimTokensFor(address,uint256,uint256,address)", holder, projectId, amount, beneficiary),
      abi.encode()
    );
  }
  
  function mock_call_transferCreditsFrom(address holder, uint256 projectId, address recipient, uint256 amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("transferCreditsFrom(address,uint256,address,uint256)", holder, projectId, recipient, amount),
      abi.encode()
    );
  }
  
  /* /// Mocked Internal Functions
  function mock_call__contextSuffixLength(uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("_contextSuffixLength()", ),
      abi.encode(_return0)
    );
  } */
  
  /* function _contextSuffixLength() internal override returns (uint256 _return0) {
      (bool _success, bytes memory _data) = address(this).call(abi.encodeWithSignature("_contextSuffixLength()", ));
      (_return0) = _success ? abi.decode(_data, (uint256)) : super._contextSuffixLength();
  } */
  

}
