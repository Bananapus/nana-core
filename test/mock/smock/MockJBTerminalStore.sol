/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IJBController, IJBDirectory, IJBPrices, IJBRulesetDataHook, IJBRulesets, IJBTerminal, IJBTerminalStore, JBAccountingContext, JBConstants, JBCurrencyAmount, JBFixedPointNumber, JBPayHookSpecification, JBPreRecordPayContext, JBPreRecordRedeemContext, JBRedeemHookSpecification, JBRuleset, JBRulesetMetadataResolver, JBTerminalStore, JBTokenAmount, ReentrancyGuard, mulDiv} from 'src/JBTerminalStore.sol';
import {ReentrancyGuard} from 'lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol';
import {mulDiv} from 'lib/prb-math/src/Common.sol';
import {IJBController} from 'src/interfaces/IJBController.sol';
import {IJBDirectory} from 'src/interfaces/IJBDirectory.sol';
import {IJBRulesetDataHook} from 'src/interfaces/IJBRulesetDataHook.sol';
import {IJBRulesets} from 'src/interfaces/IJBRulesets.sol';
import {IJBPrices} from 'src/interfaces/IJBPrices.sol';
import {IJBPrices} from 'src/interfaces/IJBPrices.sol';
import {IJBTerminal} from 'src/interfaces/terminal/IJBTerminal.sol';
import {IJBTerminalStore} from 'src/interfaces/IJBTerminalStore.sol';
import {JBConstants} from 'src/libraries/JBConstants.sol';
import {JBFixedPointNumber} from 'src/libraries/JBFixedPointNumber.sol';
import {JBCurrencyAmount} from 'src/structs/JBCurrencyAmount.sol';
import {JBRulesetMetadataResolver} from 'src/libraries/JBRulesetMetadataResolver.sol';
import {JBRuleset} from 'src/structs/JBRuleset.sol';
import {JBPayHookSpecification} from 'src/structs/JBPayHookSpecification.sol';
import {JBPreRecordPayContext} from 'src/structs/JBPreRecordPayContext.sol';
import {JBPreRecordRedeemContext} from 'src/structs/JBPreRecordRedeemContext.sol';
import {JBRedeemHookSpecification} from 'src/structs/JBRedeemHookSpecification.sol';
import {JBAccountingContext} from 'src/structs/JBAccountingContext.sol';
import {JBTokenAmount} from 'src/structs/JBTokenAmount.sol';

contract MockJBTerminalStore is JBTerminalStore, Test {

  constructor(IJBDirectory directory, IJBRulesets rulesets, IJBPrices prices) JBTerminalStore(directory, rulesets, prices) {}
  /// Mocked State Variables
  function set_balanceOf(address _key0, uint256 _key1, address _key2, uint256 _value) public {
    balanceOf[_key0][_key1][_key2] = _value;
  }
  
  function mock_call_balanceOf(address _key0, uint256 _key1, address _key2, uint256 _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("balanceOf(address,uint256,address)", _key0, _key1, _key2),
      abi.encode(_value)
    );
  }
  
  function set_usedPayoutLimitOf(address _key0, uint256 _key1, address _key2, uint256 _key3, uint256 _key4, uint256 _value) public {
    usedPayoutLimitOf[_key0][_key1][_key2][_key3][_key4] = _value;
  }
  
  function mock_call_usedPayoutLimitOf(address _key0, uint256 _key1, address _key2, uint256 _key3, uint256 _key4, uint256 _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("usedPayoutLimitOf(address,uint256,address,uint256,uint256)", _key0, _key1, _key2, _key3, _key4),
      abi.encode(_value)
    );
  }
  
  function set_usedSurplusAllowanceOf(address _key0, uint256 _key1, address _key2, uint256 _key3, uint256 _key4, uint256 _value) public {
    usedSurplusAllowanceOf[_key0][_key1][_key2][_key3][_key4] = _value;
  }
  
  function mock_call_usedSurplusAllowanceOf(address _key0, uint256 _key1, address _key2, uint256 _key3, uint256 _key4, uint256 _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("usedSurplusAllowanceOf(address,uint256,address,uint256,uint256)", _key0, _key1, _key2, _key3, _key4),
      abi.encode(_value)
    );
  }
  
  /// Mocked External Functions
  function mock_call_currentSurplusOf(address terminal, uint256 projectId, JBAccountingContext[] calldata accountingContexts, uint256 decimals, uint256 currency, uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("currentSurplusOf(address,uint256,JBAccountingContext[],uint256,uint256)", terminal, projectId, accountingContexts, decimals, currency),
      abi.encode(_return0)
    );
  }
  
  function mock_call_currentTotalSurplusOf(uint256 projectId, uint256 decimals, uint256 currency, uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("currentTotalSurplusOf(uint256,uint256,uint256)", projectId, decimals, currency),
      abi.encode(_return0)
    );
  }
  
  function mock_call_currentReclaimableSurplusOf(address terminal, uint256 projectId, JBAccountingContext[] calldata accountingContexts, uint256 decimals, uint256 currency, uint256 tokenCount, bool useTotalSurplus, uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("currentReclaimableSurplusOf(address,uint256,JBAccountingContext[],uint256,uint256,uint256,bool)", terminal, projectId, accountingContexts, decimals, currency, tokenCount, useTotalSurplus),
      abi.encode(_return0)
    );
  }
  
  function mock_call_currentReclaimableSurplusOf(uint256 projectId, uint256 tokenCount, uint256 totalSupply, uint256 surplus, uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("currentReclaimableSurplusOf(uint256,uint256,uint256,uint256)", projectId, tokenCount, totalSupply, surplus),
      abi.encode(_return0)
    );
  }
  
  function mock_call_recordPaymentFrom(address payer, JBTokenAmount calldata amount, uint256 projectId, address beneficiary, bytes calldata metadata, JBRuleset memory ruleset, uint256 tokenCount, JBPayHookSpecification[] memory hookSpecifications) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("recordPaymentFrom(address,JBTokenAmount,uint256,address,bytes)", payer, amount, projectId, beneficiary, metadata),
      abi.encode(ruleset, tokenCount, hookSpecifications)
    );
  }
  
  function mock_call_recordRedemptionFor(address holder, uint256 projectId, uint256 redeemCount, JBAccountingContext calldata accountingContext, JBAccountingContext[] calldata balanceAccountingContexts, bytes memory metadata, JBRuleset memory ruleset, uint256 reclaimAmount, JBRedeemHookSpecification[] memory hookSpecifications) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("recordRedemptionFor(address,uint256,uint256,JBAccountingContext,JBAccountingContext[],bytes)", holder, projectId, redeemCount, accountingContext, balanceAccountingContexts, metadata),
      abi.encode(ruleset, reclaimAmount, hookSpecifications)
    );
  }
  
  function mock_call_recordPayoutFor(uint256 projectId, JBAccountingContext calldata accountingContext, uint256 amount, uint256 currency, JBRuleset memory ruleset, uint256 amountPaidOut) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("recordPayoutFor(uint256,JBAccountingContext,uint256,uint256)", projectId, accountingContext, amount, currency),
      abi.encode(ruleset, amountPaidOut)
    );
  }
  
  function mock_call_recordUsedAllowanceOf(uint256 projectId, JBAccountingContext calldata accountingContext, uint256 amount, uint256 currency, JBRuleset memory ruleset, uint256 usedAmount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("recordUsedAllowanceOf(uint256,JBAccountingContext,uint256,uint256)", projectId, accountingContext, amount, currency),
      abi.encode(ruleset, usedAmount)
    );
  }
  
  function mock_call_recordAddedBalanceFor(uint256 projectId, address token, uint256 amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("recordAddedBalanceFor(uint256,address,uint256)", projectId, token, amount),
      abi.encode()
    );
  }
  
  function mock_call_recordTerminalMigration(uint256 projectId, address token, uint256 balance) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("recordTerminalMigration(uint256,address)", projectId, token),
      abi.encode(balance)
    );
  }
  
  /// Mocked Internal Functions

}
