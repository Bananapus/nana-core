// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBERC20Setup} from "./JBERC20Setup.sol";
import {SigUtils} from "./SigUtils.sol";

contract TestNonces_Local is JBERC20Setup {
    IERC20Permit _token;
    SigUtils sigUtils;

    bytes32 private immutable _hashedName = keccak256(bytes("JBToken"));
    bytes32 private immutable _hashedVersion = keccak256(bytes("1"));

    bytes32 _domain;

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function setUp() public {
        super.erc20Setup();

        _token = IERC20Permit(address(_erc20));
        _domain = keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(_token)));
        sigUtils = new SigUtils(_domain);
    }

    function test_WhenAUserHasNotCalledPermit() external view {
        // it will return zero

        uint256 _nonce = _token.nonces(_owner);

        assertEq(_nonce, 0);
    }

    function test_WhenAUserHasCalledPermit() external {
        // it will return a nonce GT zero

        (address holder, uint256 holderPk) = makeAddrAndKey("hodler");

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: holder,
            spender: address(this),
            value: 1,
            nonce: _token.nonces(holder),
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(holderPk, digest);

        vm.prank(holder);
        _token.permit(holder, address(this), 1, block.timestamp + 1 days, v, r, s);

        uint256 _nonce = _token.nonces(holder);
        assertEq(_nonce, 1);
    }
}
