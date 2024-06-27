// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockPriceFeed} from "./mock/MockPriceFeed.sol";

contract TestPermit2Terminal_Local is TestBaseWorkflow {
    uint256 private constant _WEIGHT = 1000 * 10 ** 18;

    IJBController private _controller;
    IJBTerminal private _terminal;
    IJBPrices private _prices;
    IJBTokens private _tokens;
    IERC20 private _usdc;
    IPermit2 private _permit2;
    MetadataResolverHelper private _helper;
    address private _projectOwner;

    uint256 _projectId;

    // Permit2 params.
    bytes32 DOMAIN_SEPARATOR;
    address from;
    uint256 fromPrivateKey;

    // Price.
    uint256 _nativePricePerUsd = 0.0005 * 10 ** 18; // 1/2000

    function setUp() public override {
        super.setUp();

        _controller = jbController();
        _projectOwner = multisig();
        _terminal = jbMultiTerminal();
        _prices = jbPrices();
        _tokens = jbTokens();
        _helper = metadataHelper();
        _usdc = usdcToken();
        _permit2 = permit2();

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);
        DOMAIN_SEPARATOR = permit2().DOMAIN_SEPARATOR();

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowSetCustomToken: true,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: false,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _WEIGHT;
        _rulesetConfig[0].decayRate = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = new JBFundAccessLimitGroup[](0);

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](2);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _tokensToAccept[1] = JBAccountingContext({
            token: address(usdcToken()),
            decimals: 6,
            currency: uint32(uint160(address(usdcToken())))
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept});

        // Create a first project to collect fees.
        _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        _projectId = _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedNativeUsd = new MockPriceFeed(_nativePricePerUsd, 18);
        vm.label(address(_priceFeedNativeUsd), "Mock Price Feed Native-USD");

        _prices.addPriceFeedFor({
            projectId: _projectId,
            pricingCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            unitCurrency: uint32(uint160(address(usdcToken()))),
            feed: _priceFeedNativeUsd
        });

        vm.stopPrank();
    }

    function testFuzzPayPermit2(uint256 _coins, uint256 _expiration, uint256 _deadline) public {
        // Setup: set fuzz boundaries.
        _coins = bound(_coins, 0, uint256(type(uint160).max) + 1);
        _expiration = bound(_expiration, block.timestamp + 1, type(uint48).max - 1);
        _deadline = bound(_deadline, block.timestamp + 1, type(uint256).max - 1);

        // Setup: prepare permit details for signing.
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer.PermitDetails({
            token: address(_usdc),
            amount: uint160(_coins),
            expiration: uint48(_expiration),
            nonce: 0
        });

        IAllowanceTransfer.PermitSingle memory permit =
            IAllowanceTransfer.PermitSingle({details: details, spender: address(_terminal), sigDeadline: _deadline});

        // Setup: sign permit details.
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        JBSingleAllowanceContext memory permitData = JBSingleAllowanceContext({
            sigDeadline: _deadline,
            amount: uint160(_coins),
            expiration: uint48(_expiration),
            nonce: uint48(0),
            signature: sig
        });

        // Setup: prepare data for metadata helper.
        bytes4[] memory _ids = new bytes4[](1);
        bytes[] memory _datas = new bytes[](1);
        _datas[0] = abi.encode(permitData);
        _ids[0] = _helper.getId("permit2", address(_terminal));

        // Setup: use the metadata library to encode.
        bytes memory _packedData = _helper.createMetadata(_ids, _datas);

        // Setup: give coins and approve permit2 contract.
        deal(address(_usdc), from, _coins);
        vm.prank(from);
        IERC20(address(_usdc)).approve(address(permit2()), _coins);

        if (_coins == uint256(type(uint160).max) + 1) {
            vm.expectRevert(abi.encodeWithSignature("PERMIT_ALLOWANCE_NOT_ENOUGH()"));
        }

        vm.prank(from);
        uint256 _minted = _terminal.pay({
            projectId: _projectId,
            amount: _coins,
            token: address(_usdc),
            beneficiary: from,
            minReturnedTokens: 0,
            memo: "Take my permitted money!",
            metadata: _packedData
        });

        if (_coins < uint256(type(uint160).max) + 1) {
            // Check: that tokens were transfered.
            assertEq(_usdc.balanceOf(address(_terminal)), _coins);

            // Check: that payer receives project token/balance.
            assertEq(_tokens.totalBalanceOf(from, _projectId), _minted);
        }
    }

    function testFuzzAddToBalancePermit2(uint256 _coins, uint256 _expiration, uint256 _deadline) public {
        // Setup: set fuzz boundaries.
        _coins = bound(_coins, 0, uint256(type(uint160).max) + 1);
        _expiration = bound(_expiration, block.timestamp + 1, type(uint48).max - 1);
        _deadline = bound(_deadline, block.timestamp + 1, type(uint256).max - 1);

        // Setup: prepare permit details for signing.
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer.PermitDetails({
            token: address(_usdc),
            amount: uint160(_coins),
            expiration: uint48(_expiration),
            nonce: 0
        });

        IAllowanceTransfer.PermitSingle memory permit =
            IAllowanceTransfer.PermitSingle({details: details, spender: address(_terminal), sigDeadline: _deadline});

        // Setup: sign permit details.
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        JBSingleAllowanceContext memory permitData = JBSingleAllowanceContext({
            sigDeadline: _deadline,
            amount: uint160(_coins),
            expiration: uint48(_expiration),
            nonce: uint48(0),
            signature: sig
        });

        // Setup: prepare data for metadata helper.
        bytes4[] memory _ids = new bytes4[](1);
        bytes[] memory _datas = new bytes[](1);
        _datas[0] = abi.encode(permitData);
        _ids[0] = _helper.getId("permit2", address(_terminal));

        // Setup: use the metadata library to encode.
        bytes memory _packedData = _helper.createMetadata(_ids, _datas);

        // Setup: give coins and approve permit2 contract.
        deal(address(_usdc), from, _coins);
        vm.prank(from);
        IERC20(address(_usdc)).approve(address(permit2()), _coins);

        if (_coins == uint256(type(uint160).max) + 1) {
            vm.expectRevert(abi.encodeWithSignature("PERMIT_ALLOWANCE_NOT_ENOUGH()"));
        }

        // Test: add to balance using permit2 data, which should transfer tokens.
        vm.prank(from);
        _terminal.addToBalanceOf(_projectId, address(_usdc), _coins, false, "testing permit2", _packedData);

        // Check: that tokens were transferred.
        if (_coins < uint256(type(uint160).max) + 1) assertEq(_usdc.balanceOf(address(_terminal)), _coins);
    }

    function testPayAmountGtMaxPermit() public {
        // Setup: refs
        uint160 _permitAmount = type(uint160).max;
        uint256 _payAmount = type(uint256).max;
        uint256 _sigDeadline = block.timestamp + 1;
        uint48 _expiration = type(uint48).max;
        uint48 _nonce = 0;

        // Setup: prepare permit details for signing.
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer.PermitDetails({
            token: address(_usdc),
            amount: _permitAmount,
            expiration: _expiration,
            nonce: 0
        });

        IAllowanceTransfer.PermitSingle memory permit =
            IAllowanceTransfer.PermitSingle({details: details, spender: address(_terminal), sigDeadline: _sigDeadline});

        // Setup: sign permit details.
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        JBSingleAllowanceContext({
            sigDeadline: _sigDeadline,
            amount: _permitAmount,
            expiration: _expiration,
            nonce: _nonce,
            signature: sig
        });

        vm.expectRevert(abi.encodeWithSignature("OVERFLOW_ALERT()"));

        vm.prank(from);
        _terminal.pay({
            projectId: _projectId,
            amount: _payAmount,
            token: address(_usdc),
            beneficiary: from,
            minReturnedTokens: 0,
            memo: "Take my permitted money!",
            metadata: ""
        });
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
}
