// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestAddToBalanceOf_Local is JBMultiTerminalSetup {
    // Permit2
    IPermit2 private _permit2;

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

    // Permit2 params.
    bytes32 DOMAIN_SEPARATOR;
    address from;
    uint256 fromPrivateKey = 0x12341234;

    function setUp() public {
        super.multiTerminalSetup();

        from = vm.addr(fromPrivateKey);
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
        mockExpect(address(store), abi.encodeCall(IJBTerminalStore.recordAddedBalanceFor, (_projectId, _native, 0)), "");

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
            ""
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
            ""
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
            ""
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

        vm.expectRevert(JBMultiTerminal.JBMultiTerminal_TokenNotAccepted.selector);

        _terminal.addToBalanceOf{value: payAmount}({
            projectId: _projectId,
            token: _native,
            amount: payAmount,
            shouldReturnHeldFees: _shouldReturnHeldFees,
            memo: "",
            metadata: ""
        });
    }

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

        vm.expectRevert(JBMultiTerminal.JBMultiTerminal_NoMsgValueAllowed.selector);

        _terminal.addToBalanceOf{value: 1}({
            projectId: _projectId,
            token: _usdc,
            amount: payAmount,
            shouldReturnHeldFees: _shouldReturnHeldFees,
            memo: "",
            metadata: ""
        });
    }

    modifier whenPayMetadataContainsPermitData() {
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

        _;
    }

    /// Permit2 signature helpers.
    /// (required because `permit2/test/utils/PermitSignature.sol` imports `draft-EIP712.sol` which is no longer a
    /// draft.)

    bytes32 public constant _PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");

    bytes32 public constant _PERMIT_SINGLE_TYPEHASH = keccak256(
        "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

    bytes32 public constant _PERMIT_BATCH_TYPEHASH = keccak256(
        "PermitBatch(PermitDetails[] details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    bytes32 public constant _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    function getPermitSignatureRaw(
        IAllowanceTransfer.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    )
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 permitHash = keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, permit.details));

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(_PERMIT_SINGLE_TYPEHASH, permitHash, permit.spender, permit.sigDeadline))
            )
        );

        (v, r, s) = vm.sign(privateKey, msgHash);
    }

    function getPermitSignature(
        IAllowanceTransfer.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    )
        internal
        pure
        returns (bytes memory sig)
    {
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, privateKey, domainSeparator);
        return bytes.concat(r, s, bytes1(v));
    }

    function test_GivenThePermitAllowanceLtAmount() external whenPayMetadataContainsPermitData {
        // it will revert PERMIT_ALLOWANCE_NOT_ENOUGH

        uint256 expiration = block.timestamp + 10;
        uint256 deadline = block.timestamp + 10;
        payAmount = 1e18;

        // Setup: prepare permit details for signing.
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer.PermitDetails({
            token: address(_usdc),
            amount: uint160(payAmount),
            expiration: uint48(expiration),
            nonce: 0
        });

        IAllowanceTransfer.PermitSingle memory permit =
            IAllowanceTransfer.PermitSingle({details: details, spender: address(_terminal), sigDeadline: deadline});

        // Setup: sign permit details.
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        JBSingleAllowance memory permitData = JBSingleAllowance({
            sigDeadline: deadline,
            amount: uint160(1),
            expiration: uint48(expiration),
            nonce: uint48(0),
            signature: sig
        });

        // Setup: prepare data for metadata helper.
        bytes4[] memory _ids = new bytes4[](1);
        bytes[] memory _datas = new bytes[](1);
        _datas[0] = abi.encode(permitData);
        _ids[0] = _metadataHelper.getId("permit2", address(_terminal));

        // Setup: use the metadata library to encode.
        bytes memory _packedData = _metadataHelper.createMetadata(_ids, _datas);

        vm.expectRevert(JBMultiTerminal.JBMultiTerminal_PermitAllowanceNotEnough.selector);

        vm.startPrank(from);

        _terminal.addToBalanceOf({
            projectId: _projectId,
            token: _usdc,
            amount: payAmount,
            shouldReturnHeldFees: false,
            memo: "",
            metadata: _packedData
        });
    }

    // unfortunately the interface is bugged for the encodeCall here, skipping for now to revisit.
    /* function test_GivenPermitAllowanceIsGood() external whenPayMetadataContainsPermitData {
        // it will set permit allowance to spend tokens for user via permit2

        uint256 expiration = block.timestamp + 10;
        uint256 deadline = block.timestamp + 10;
        payAmount = 1e18;

        // Setup: prepare permit details for signing.
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer.PermitDetails({
            token: address(_usdc),
            amount: uint160(payAmount),
            expiration: uint48(expiration),
            nonce: 0
        });

        IAllowanceTransfer.PermitSingle memory permit =
            IAllowanceTransfer.PermitSingle({details: details, spender: address(_terminal), sigDeadline: deadline});

        // Setup: sign permit details.
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        JBSingleAllowance memory permitData = JBSingleAllowance({
            sigDeadline: deadline,
            amount: uint160(payAmount),
            expiration: uint48(expiration),
            nonce: uint48(0),
            signature: sig
        });

        // Setup: prepare data for metadata helper.
        bytes4[] memory _ids = new bytes4[](1);
        bytes[] memory _datas = new bytes[](1);
        _datas[0] = abi.encode(permitData);
        _ids[0] = _metadataHelper.getId("permit2", _terminal)

        // Setup: use the metadata library to encode.
        bytes memory _packedData = _metadataHelper.createMetadata(_ids, _datas);

        mockExpect(
            address(permit2),
            abi.encodeCall(IAllowanceTransfer.permit(address, PermitSingle, bytes), (address(from), permit, sig)),
            ""
        );

        vm.startPrank(from);
        
        _terminal.addToBalanceOf({
            projectId: _projectId,
            token: _usdc,
            amount: payAmount,
            shouldReturnHeldFees: false,
            memo: "",
            metadata: _packedData
        });

    } */
}
