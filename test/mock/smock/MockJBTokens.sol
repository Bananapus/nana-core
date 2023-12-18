/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {EIP712, IJBDirectory, IJBPermissions, IJBProjects, IJBToken, IJBTokens, JBControlled, JBERC20, JBPermissionIds, JBTokens} from 'src/JBTokens.sol';
import {EIP712} from 'lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol';
import {JBControlled} from 'src/abstract/JBControlled.sol';
import {IJBDirectory} from 'src/interfaces/IJBDirectory.sol';
import {IJBPermissions} from 'src/interfaces/IJBPermissions.sol';
import {IJBProjects} from 'src/interfaces/IJBProjects.sol';
import {IJBToken} from 'src/interfaces/IJBToken.sol';
import {IJBTokens} from 'src/interfaces/IJBTokens.sol';
import {JBPermissionIds} from 'src/libraries/JBPermissionIds.sol';
import {JBERC20} from 'src/JBERC20.sol';

contract MockJBTokens is JBTokens, Test {

  constructor(IJBDirectory directory) JBTokens(directory) {}
  /// Mocked State Variables
  function set_tokenOf(uint256 _key0, IJBToken _value) public {
    tokenOf[_key0] = _value;
  }
  
  function mock_call_tokenOf(uint256 _key0, IJBToken _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("tokenOf(uint256)", _key0),
      abi.encode(_value)
    );
  }
  
  function set_projectIdOf(IJBToken _key0, uint256 _value) public {
    projectIdOf[_key0] = _value;
  }
  
  function mock_call_projectIdOf(IJBToken _key0, uint256 _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("projectIdOf(IJBToken)", _key0),
      abi.encode(_value)
    );
  }
  
  function set_totalCreditSupplyOf(uint256 _key0, uint256 _value) public {
    totalCreditSupplyOf[_key0] = _value;
  }
  
  function mock_call_totalCreditSupplyOf(uint256 _key0, uint256 _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("totalCreditSupplyOf(uint256)", _key0),
      abi.encode(_value)
    );
  }
  
  function set_creditBalanceOf(address _key0, uint256 _key1, uint256 _value) public {
    creditBalanceOf[_key0][_key1] = _value;
  }
  
  function mock_call_creditBalanceOf(address _key0, uint256 _key1, uint256 _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("creditBalanceOf(address,uint256)", _key0, _key1),
      abi.encode(_value)
    );
  }
  
  /// Mocked External Functions
  function mock_call_totalBalanceOf(address holder, uint256 projectId, uint256 balance) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("totalBalanceOf(address,uint256)", holder, projectId),
      abi.encode(balance)
    );
  }
  
  function mock_call_totalSupplyOf(uint256 projectId, uint256 totalSupply) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("totalSupplyOf(uint256)", projectId),
      abi.encode(totalSupply)
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
  
  function mock_call_mintFor(address holder, uint256 projectId, uint256 amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("mintFor(address,uint256,uint256)", holder, projectId, amount),
      abi.encode()
    );
  }
  
  function mock_call_burnFrom(address holder, uint256 projectId, uint256 amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("burnFrom(address,uint256,uint256)", holder, projectId, amount),
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
  
  /// Mocked Internal Functions

}
