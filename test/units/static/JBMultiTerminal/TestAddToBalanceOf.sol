// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestAddToBalanceOf_Local is JBMultiTerminalSetup {
    uint256 _projectId = 1;
    address _native = JBConstants.NATIVE_TOKEN;
    uint256 _nativeCurrency = uint32(uint160(_native));
    address _usdc = makeAddr("USDC");
    uint256 _usdcCurrency = uint32(uint160(_usdc));
    uint256 _terminalUSDCBalance = 1e18;

    bool _shouldReturnHeldFees;

    function setUp() public {
        super.multiTerminalSetup();
    }

    modifier whenShouldReturnHeldFeesEqTrue() {
        _shouldReturnHeldFees = true;

        _;
    }

    function test_GivenReturnAmountIsZero() external whenShouldReturnHeldFeesEqTrue {
        // it will set heldFeesOf project to the previously set heldFee

        // Accounting Context to set
        JBAccountingContext memory _context =
            JBAccountingContext({token: _native, decimals: 18, currency: uint32(_nativeCurrency)});

        // Find the storage slot
        bytes32 contextSlot = keccak256(abi.encode(_projectId, uint256(0)));
        bytes32 slot = keccak256(abi.encode(_native, contextSlot));

        // Set storage
        vm.store(address(_terminal), slot, bytes32(abi.encode(_context)));

        JBAccountingContext memory _storedContext = _terminal.accountingContextForTokenOf(_projectId, _native);
        assertEq(_storedContext.token, _native);

        // Fee to set
        JBFee[] memory fees = new JBFee[](1);

        fees[0] = JBFee({
            amount: 1,
            beneficiary: address(this),
            unlockTimestamp: 0
        });

         // Find the storage slot for fees array
        bytes32 feeSlot = keccak256(abi.encode(_projectId, uint256(2)));
        bytes32 slotForArrayLength = keccak256(abi.encode(_native, feeSlot));

        // Set the length of the fees array in the storage slot
        vm.store(address(_terminal), slotForArrayLength, bytes32(uint256(1)));

        // First item should be stored at the next slot
        bytes32 firstItemSlot = keccak256(abi.encodePacked(slotForArrayLength));

        vm.store(address(_terminal), firstItemSlot, bytes32(uint256(1)));

        JBFee[] memory setFees = _terminal.heldFeesOf(_projectId, _native);
        assertEq(setFees[0].amount, 1);

        /* // mock token balanceOf call
        mockExpect(
            _usdc,
            abi.encodeCall(IERC20.balanceOf, address(_terminal)),
            abi.encode(_terminalUSDCBalance)
        ); */

        // mock call to store recordAddedBalanceFor
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordAddedBalanceFor, (_projectId, _native, 0)),
            abi.encode()
        );

        _terminal.addToBalanceOf({
            projectId: _projectId,
            token: _native,
            amount: 0,
            shouldReturnHeldFees: _shouldReturnHeldFees,
            memo: "",
            metadata: ""
        });

        // Heldfee should remain
        JBFee[] memory feesAfter = _terminal.heldFeesOf(_projectId, _native);
        assertEq(feesAfter[0].amount, 1);
    }

    function test_GivenReturnAmountIsNon_zeroAndLeftoverAmountGTEQAmountFromFee()
        external
        whenShouldReturnHeldFeesEqTrue
    {
        // it will return feeAmountIn
    }

    function test_GivenReturnAmountIsNon_zeroAndLeftoverAmountLTAmountFromFee()
        external
        whenShouldReturnHeldFeesEqTrue
    {
        // it will set heldFeesOf return feeAmountFrom and set leftoverAmount to zero
    }

    function test_WhenShouldReturnHeldFeesEqFalse() external {
        // it will call terminalstore recordAddedBalanceFor and emit AddToBalance
    }

    function test_WhenTheProjectDNHAccountingContextForTheToken() external {
        // it will revert TOKEN_NOT_ACCEPTED
    }

    function test_WhenTheTerminalsTokenEqNativeToken() external {
        // it will use msg.value
    }

    function test_WhenTheTerminalsTokenEqNativeTokenAndMsgvalueEqZero() external {
        // it will revert NO_MSG_VALUE_ALLOWED
    }

    function test_WhenTheTerminalIsCallingItself() external {
        // it will not transfer
    }

    modifier whenPayMetadataContainsPermitData() {
        _;
    }

    function test_GivenThePermitAllowanceLtAmount() external whenPayMetadataContainsPermitData {
        // it will revert PERMIT_ALLOWANCE_NOT_ENOUGH
    }

    function test_GivenPermitAllowanceIsGood() external whenPayMetadataContainsPermitData {
        // it will set permit allowance to spend tokens for user via permit2
    }
}
