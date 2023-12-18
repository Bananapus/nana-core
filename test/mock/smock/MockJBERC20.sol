/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC20, ERC20Permit, ERC20Votes, IJBToken, JBERC20, Nonces, Ownable} from 'src/JBERC20.sol';
import {Ownable} from 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import {ERC20Votes, ERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol';
import {ERC20Permit, Nonces} from 'lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {IJBToken} from 'src/interfaces/IJBToken.sol';

contract MockJBERC20 is JBERC20, Test {

  constructor(string memory name, string memory symbol, address owner) JBERC20(name, symbol, owner) {}
  /// Mocked State Variables
  /// Mocked External Functions
  function mock_call_decimals(uint8 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("decimals()"),
      abi.encode(_return0)
    );
  }
  
  function mock_call_totalSupply(uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("totalSupply()"),
      abi.encode(_return0)
    );
  }
  
  function mock_call_balanceOf(address account, uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("balanceOf(address)", account),
      abi.encode(_return0)
    );
  }
  
  function mock_call_mint(address account, uint256 amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("mint(address,uint256)", account, amount),
      abi.encode()
    );
  }
  
  function mock_call_burn(address account, uint256 amount) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("burn(address,uint256)", account, amount),
      abi.encode()
    );
  }
  
  function mock_call_nonces(address owner, uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("nonces(address)", owner),
      abi.encode(_return0)
    );
  }
  
  /// Mocked Internal Functions
  function mock_call__update(address from, address to, uint256 value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("_update(address,address,uint256)", from, to, value),
      abi.encode()
    );
  }
  
  /* function _update(address from, address to, uint256 value) internal override  {
      (bool _success, bytes memory _data) = address(this).call(abi.encodeWithSignature("_update(address,address,uint256)", from, to, value));
      () = _success ? abi.decode(_data, ()) : super._update(from, to, value);
  } */
  

}
