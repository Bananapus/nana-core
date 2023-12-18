/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Address, Context, ERC165Checker, ERC2771Context, IAllowanceTransfer, IERC165, IERC20, IERC20Metadata, IJBController, IJBDirectory, IJBFeeTerminal, IJBFeelessAddresses, IJBMultiTerminal, IJBPayoutTerminal, IJBPermissioned, IJBPermissions, IJBPermitTerminal, IJBProjects, IJBRedeemTerminal, IJBSplitHook, IJBSplits, IJBTerminal, IJBTerminalStore, IPermit2, JBAccountingContext, JBConstants, JBFee, JBFees, JBMetadataResolver, JBMultiTerminal, JBPayHookSpecification, JBPermissionIds, JBPermissioned, JBPostRecordPayContext, JBPostRecordRedeemContext, JBRedeemHookSpecification, JBRuleset, JBRulesetMetadataResolver, JBSingleAllowanceContext, JBSplit, JBSplitHookContext, JBTokenAmount, SafeERC20, mulDiv} from 'src/JBMultiTerminal.sol';
import {Address} from 'lib/openzeppelin-contracts/contracts/utils/Address.sol';
import {Context} from 'lib/openzeppelin-contracts/contracts/utils/Context.sol';
import {IERC165} from 'lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol';
import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {ERC2771Context} from 'lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol';
import {IERC20Metadata} from 'lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC165Checker} from 'lib/openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol';
import {mulDiv} from 'lib/prb-math/src/Common.sol';
import {IPermit2} from 'lib/permit2/src/interfaces/IPermit2.sol';
import {IAllowanceTransfer} from 'lib/permit2/src/interfaces/IPermit2.sol';
import {IJBController} from 'src/interfaces/IJBController.sol';
import {IJBDirectory} from 'src/interfaces/IJBDirectory.sol';
import {IJBFeelessAddresses} from 'src/interfaces/IJBFeelessAddresses.sol';
import {IJBSplits} from 'src/interfaces/IJBSplits.sol';
import {IJBPermissioned} from 'src/interfaces/IJBPermissioned.sol';
import {IJBPermissions} from 'src/interfaces/IJBPermissions.sol';
import {IJBProjects} from 'src/interfaces/IJBProjects.sol';
import {IJBTerminalStore} from 'src/interfaces/IJBTerminalStore.sol';
import {IJBSplitHook} from 'src/interfaces/IJBSplitHook.sol';
import {JBConstants} from 'src/libraries/JBConstants.sol';
import {JBFees} from 'src/libraries/JBFees.sol';
import {JBRulesetMetadataResolver} from 'src/libraries/JBRulesetMetadataResolver.sol';
import {JBMetadataResolver} from 'src/libraries/JBMetadataResolver.sol';
import {JBPermissionIds} from 'src/libraries/JBPermissionIds.sol';
import {JBPostRecordRedeemContext} from 'src/structs/JBPostRecordRedeemContext.sol';
import {JBPostRecordPayContext} from 'src/structs/JBPostRecordPayContext.sol';
import {JBFee} from 'src/structs/JBFee.sol';
import {JBRuleset} from 'src/structs/JBRuleset.sol';
import {JBPayHookSpecification} from 'src/structs/JBPayHookSpecification.sol';
import {JBRedeemHookSpecification} from 'src/structs/JBRedeemHookSpecification.sol';
import {JBSingleAllowanceContext} from 'src/structs/JBSingleAllowanceContext.sol';
import {JBSplit} from 'src/structs/JBSplit.sol';
import {JBSplitHookContext} from 'src/structs/JBSplitHookContext.sol';
import {JBAccountingContext} from 'src/structs/JBAccountingContext.sol';
import {JBTokenAmount} from 'src/structs/JBTokenAmount.sol';
import {JBPermissioned} from 'src/abstract/JBPermissioned.sol';
import {IJBMultiTerminal} from 'src/interfaces/terminal/IJBMultiTerminal.sol';
import {IJBFeeTerminal} from 'src/interfaces/terminal/IJBFeeTerminal.sol';
import {IJBTerminal} from 'src/interfaces/terminal/IJBTerminal.sol';
import {IJBRedeemTerminal} from 'src/interfaces/terminal/IJBRedeemTerminal.sol';
import {IJBPayoutTerminal} from 'src/interfaces/terminal/IJBPayoutTerminal.sol';
import {IJBPermitTerminal} from 'src/interfaces/terminal/IJBPermitTerminal.sol';

contract MockJBMultiTerminal is JBMultiTerminal, Test {

  constructor(IJBPermissions permissions, IJBProjects projects, IJBDirectory directory, IJBSplits splits, IJBTerminalStore store, IJBFeelessAddresses feelessAddresses, IPermit2 permit2, address trustedForwarder) JBMultiTerminal(permissions, projects, directory, splits, store, feelessAddresses, permit2, trustedForwarder) {}
  /// Mocked State Variables
  /// Mocked External Functions
  function mock_call_accountingContextForTokenOf(uint256 projectId, address token, JBAccountingContext memory _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("accountingContextForTokenOf(uint256,address)", projectId, token),
      abi.encode(_return0)
    );
  }
  
  function mock_call_accountingContextsOf(uint256 projectId, JBAccountingContext[] memory _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("accountingContextsOf(uint256)", projectId),
      abi.encode(_return0)
    );
  }
  
  function mock_call_currentSurplusOf(uint256 projectId, uint256 decimals, uint256 currency, uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("currentSurplusOf(uint256,uint256,uint256)", projectId, decimals, currency),
      abi.encode(_return0)
    );
  }
  
  function mock_call_heldFeesOf(uint256 projectId, address token, JBFee[] memory _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("heldFeesOf(uint256,address)", projectId, token),
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
  
  function mock_call_pay(uint256 projectId, address token, uint256 amount, address beneficiary, uint256 minReturnedTokens, string calldata memo, bytes calldata metadata, uint256 beneficiaryTokenCount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("pay(uint256,address,uint256,address,uint256,string,bytes)", projectId, token, amount, beneficiary, minReturnedTokens, memo, metadata),
      abi.encode(beneficiaryTokenCount)
    );
  }
  
  function mock_call_addToBalanceOf(uint256 projectId, address token, uint256 amount, bool shouldReturnHeldFees, string calldata memo, bytes calldata metadata) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("addToBalanceOf(uint256,address,uint256,bool,string,bytes)", projectId, token, amount, shouldReturnHeldFees, memo, metadata),
      abi.encode()
    );
  }
  
  function mock_call_redeemTokensOf(address holder, uint256 projectId, address tokenToReclaim, uint256 redeemCount, uint256 minTokensReclaimed, address payable beneficiary, bytes calldata metadata, uint256 reclaimAmount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("redeemTokensOf(address,uint256,address,uint256,uint256,address payable,bytes)", holder, projectId, tokenToReclaim, redeemCount, minTokensReclaimed, beneficiary, metadata),
      abi.encode(reclaimAmount)
    );
  }
  
  function mock_call_sendPayoutsOf(uint256 projectId, address token, uint256 amount, uint256 currency, uint256 minTokensPaidOut, uint256 amountPaidOut) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("sendPayoutsOf(uint256,address,uint256,uint256,uint256)", projectId, token, amount, currency, minTokensPaidOut),
      abi.encode(amountPaidOut)
    );
  }
  
  function mock_call_useAllowanceOf(uint256 projectId, address token, uint256 amount, uint256 currency, uint256 minTokensPaidOut, address payable beneficiary, string calldata memo, uint256 amountPaidOut) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("useAllowanceOf(uint256,address,uint256,uint256,uint256,address payable,string)", projectId, token, amount, currency, minTokensPaidOut, beneficiary, memo),
      abi.encode(amountPaidOut)
    );
  }
  
  function mock_call_migrateBalanceOf(uint256 projectId, address token, IJBTerminal to, uint256 balance) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("migrateBalanceOf(uint256,address,IJBTerminal)", projectId, token, to),
      abi.encode(balance)
    );
  }
  
  function mock_call_processHeldFeesOf(uint256 projectId, address token) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("processHeldFeesOf(uint256,address)", projectId, token),
      abi.encode()
    );
  }
  
  function mock_call_addAccountingContextsFor(uint256 projectId, address[] calldata tokens) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("addAccountingContextsFor(uint256,address[])", projectId, tokens),
      abi.encode()
    );
  }
  
  function mock_call_executeProcessFee(uint256 projectId, address token, uint256 amount, address beneficiary, IJBTerminal feeTerminal) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("executeProcessFee(uint256,address,uint256,address,IJBTerminal)", projectId, token, amount, beneficiary, feeTerminal),
      abi.encode()
    );
  }
  
  function mock_call_executePayout(JBSplit calldata split, uint256 projectId, address token, uint256 amount, address originalMessageSender, uint256 netPayoutAmount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("executePayout(JBSplit,uint256,address,uint256,address)", split, projectId, token, amount, originalMessageSender),
      abi.encode(netPayoutAmount)
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
