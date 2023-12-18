/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC165, IJBDirectory, IJBFundAccessLimits, JBControlled, JBCurrencyAmount, JBFundAccessLimitGroup, JBFundAccessLimits} from 'src/JBFundAccessLimits.sol';
import {ERC165} from 'lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol';
import {JBControlled} from 'src/abstract/JBControlled.sol';
import {IJBFundAccessLimits} from 'src/interfaces/IJBFundAccessLimits.sol';
import {IJBDirectory} from 'src/interfaces/IJBDirectory.sol';
import {JBFundAccessLimitGroup} from 'src/structs/JBFundAccessLimitGroup.sol';
import {JBCurrencyAmount} from 'src/structs/JBCurrencyAmount.sol';

contract MockJBFundAccessLimits is JBFundAccessLimits, Test {

  constructor(IJBDirectory directory) JBFundAccessLimits(directory) {}
  /// Mocked State Variables
  /// Mocked External Functions
  function mock_call_payoutLimitsOf(uint256 projectId, uint256 rulesetId, address terminal, address token, JBCurrencyAmount[] memory payoutLimits) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("payoutLimitsOf(uint256,uint256,address,address)", projectId, rulesetId, terminal, token),
      abi.encode(payoutLimits)
    );
  }
  
  function mock_call_payoutLimitOf(uint256 projectId, uint256 rulesetId, address terminal, address token, uint256 currency, uint256 payoutLimit) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("payoutLimitOf(uint256,uint256,address,address,uint256)", projectId, rulesetId, terminal, token, currency),
      abi.encode(payoutLimit)
    );
  }
  
  function mock_call_surplusAllowancesOf(uint256 projectId, uint256 rulesetId, address terminal, address token, JBCurrencyAmount[] memory surplusAllowances) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("surplusAllowancesOf(uint256,uint256,address,address)", projectId, rulesetId, terminal, token),
      abi.encode(surplusAllowances)
    );
  }
  
  function mock_call_surplusAllowanceOf(uint256 projectId, uint256 rulesetId, address terminal, address token, uint256 currency, uint256 surplusAllowance) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("surplusAllowanceOf(uint256,uint256,address,address,uint256)", projectId, rulesetId, terminal, token, currency),
      abi.encode(surplusAllowance)
    );
  }
  
  function mock_call_setFundAccessLimitsFor(uint256 projectId, uint256 rulesetId, JBFundAccessLimitGroup[] calldata fundAccessLimitGroup) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setFundAccessLimitsFor(uint256,uint256,JBFundAccessLimitGroup[])", projectId, rulesetId, fundAccessLimitGroup),
      abi.encode()
    );
  }
  
  /// Mocked Internal Functions

}
