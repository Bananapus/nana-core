// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestAddToBalanceOf_Local is JBMultiTerminalSetup {
    // global constants
    uint256 _projectId = 1;
    address _native = JBConstants.NATIVE_TOKEN;
    uint256 _nativeCurrency = uint32(uint160(_native));
    address _usdc = makeAddr("USDC");
    uint256 _usdcCurrency = uint32(uint160(_usdc));
    uint256 _terminalUSDCBalance = 1e18;

    // set by modifiers
    uint256 payAmount;
    uint256 feeAmount;
    uint256 feeAmountIn;
    uint256 amountFromFee;
    uint256 leftOverAmount;
    bool _shouldReturnHeldFees;

    function setUp() public {
        super.multiTerminalSetup();
    }

    modifier whenNativeTokenIsAccepted() {
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

        _;
    }

    modifier whenShouldReturnHeldFeesEqTrue() {
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

        // Find the storage slot for fees array
        bytes32 feeSlot = keccak256(abi.encode(_projectId, uint256(2)));
        bytes32 slotForArrayLength = keccak256(abi.encode(_native, feeSlot));

        // Set the length of the fees array in the storage slot
        vm.store(address(_terminal), slotForArrayLength, bytes32(uint256(1)));

        // First item should be stored at the next slot
        bytes32 firstItemSlot = keccak256(abi.encodePacked(slotForArrayLength));

        feeAmount = 1e9;

        vm.store(address(_terminal), firstItemSlot, bytes32(feeAmount));

        JBFee[] memory setFees = _terminal.heldFeesOf(_projectId, _native);
        assertEq(setFees[0].amount, feeAmount);

        payAmount = 2e18;
        feeAmountIn = JBFees.feeAmountIn(feeAmount, 25);

        amountFromFee = feeAmount - feeAmountIn;
        leftOverAmount = payAmount - amountFromFee;

        _shouldReturnHeldFees = true;

        _;
    }

    function test_GivenReturnAmountIsZero() external whenShouldReturnHeldFeesEqTrue {
        // it will set heldFeesOf project to the previously set heldFee

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
        assertEq(feesAfter[0].amount, feeAmount);
    }

    function test_GivenReturnAmountIsNon_zeroAndLeftoverAmountGTEQAmountFromFee()
        external
        whenShouldReturnHeldFeesEqTrue
    {
        // it will return leftoverAmount - amountFromFee and return the held fee to beneficiary

        // mock call to store recordAddedBalanceFor
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordAddedBalanceFor, (_projectId, _native, payAmount + feeAmountIn)),
            abi.encode()
        );

        vm.expectEmit();
        emit IJBFeeTerminal.ReturnHeldFees(_projectId, _native, payAmount, feeAmountIn, leftOverAmount, address(this));

        _terminal.addToBalanceOf{value: payAmount}({
            projectId: _projectId,
            token: _native,
            amount: payAmount,
            shouldReturnHeldFees: _shouldReturnHeldFees,
            memo: "",
            metadata: ""
        });

        // Heldfee should be erased
        JBFee[] memory feesAfter = _terminal.heldFeesOf(_projectId, _native);
        assertEq(feesAfter.length, 0);
    }

    function test_GivenReturnAmountIsNon_zeroAndLeftoverAmountLTAmountFromFee()
        external
        whenShouldReturnHeldFeesEqTrue
    {
        // it will set heldFeesOf return feeAmountFrom and set leftoverAmount to zero
        uint256 lowerPayAmount = 1e8;
        uint256 feeA = JBFees.feeAmountIn(feeAmount, 25);
        uint256 returnedFee = mulDiv(lowerPayAmount, 25, JBConstants.MAX_FEE);

        // mock call to store recordAddedBalanceFor
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordAddedBalanceFor, (_projectId, _native, lowerPayAmount + returnedFee)),
            abi.encode()
        );

        vm.expectEmit();
        emit IJBFeeTerminal.ReturnHeldFees(_projectId, _native, lowerPayAmount, returnedFee, 0, address(this));

        _terminal.addToBalanceOf{value: lowerPayAmount}({
            projectId: _projectId,
            token: _native,
            amount: lowerPayAmount,
            shouldReturnHeldFees: _shouldReturnHeldFees,
            memo: "",
            metadata: ""
        });

        uint256 newFeeAmount = (feeAmount - feeA) - lowerPayAmount;

        // Heldfee should be a new amount
        JBFee[] memory feesAfter = _terminal.heldFeesOf(_projectId, _native);
        assertEq(feesAfter[0].amount, newFeeAmount);
    }

    function test_WhenShouldReturnHeldFeesEqFalse() external whenNativeTokenIsAccepted {
        // it will call terminalstore recordAddedBalanceFor and emit AddToBalance

        // mock call to store recordAddedBalanceFor
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordAddedBalanceFor, (_projectId, _native, payAmount + feeAmountIn)),
            abi.encode()
        );

        vm.expectEmit();
        emit IJBTerminal.AddToBalance(_projectId, payAmount, 0, "", "", address(this));

        _terminal.addToBalanceOf{value: payAmount}({
            projectId: _projectId,
            token: _native,
            amount: payAmount,
            shouldReturnHeldFees: _shouldReturnHeldFees,
            memo: "",
            metadata: ""
        });
    }

    function test_WhenTheProjectDNHAccountingContextForTheToken() external {
        // it will revert TOKEN_NOT_ACCEPTED

        vm.expectRevert(abi.encodeWithSignature("TOKEN_NOT_ACCEPTED()"));

        _terminal.addToBalanceOf{value: payAmount}({
            projectId: _projectId,
            token: _native,
            amount: payAmount,
            shouldReturnHeldFees: _shouldReturnHeldFees,
            memo: "",
            metadata: ""
        });

    }

    /* function test_WhenTheTerminalsTokenEqNativeToken() external {
        // it will use msg.value
        // tested above
    } */

    function test_WhenTheSpecifiedTokenDNEQNativeTokenAndMsgvalueEqZero() external {
        // it will revert NO_MSG_VALUE_ALLOWED

        // Accounting Context to set
        JBAccountingContext memory _context =
            JBAccountingContext({token: _usdc, decimals: 18, currency: uint32(_usdcCurrency)});

        // Find the storage slot
        bytes32 contextSlot = keccak256(abi.encode(_projectId, uint256(0)));
        bytes32 slot = keccak256(abi.encode(_usdc, contextSlot));

        // Set storage
        vm.store(address(_terminal), slot, bytes32(abi.encode(_context)));

        JBAccountingContext memory _storedContext = _terminal.accountingContextForTokenOf(_projectId, _usdc);
        assertEq(_storedContext.token, _usdc);

        vm.expectRevert(abi.encodeWithSignature("NO_MSG_VALUE_ALLOWED()"));

        _terminal.addToBalanceOf{value: 1}({
            projectId: _projectId,
            token: _usdc,
            amount: payAmount,
            shouldReturnHeldFees: _shouldReturnHeldFees,
            memo: "",
            metadata: ""
        });

    }

    /* function test_WhenTheTerminalIsCallingItself() external {
        // it will not transfer
        // not sure how to test this
    } */

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
