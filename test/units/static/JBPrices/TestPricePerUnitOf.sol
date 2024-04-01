// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBPricesSetup} from "./JBPricesSetup.sol";

contract TestPricePerUnitOf_Local is JBPricesSetup {
    IJBPriceFeed _feed = IJBPriceFeed(makeAddr("priceFeed"));
    uint256 DEFAULT_PROJECT_ID = 0;
    uint256 _projectId = 1;
    uint256 _defaultDirectPrice = 1_000_000_000;
    uint256 _directPrice = 2_000_000_000;
    uint256 _inversePrice = 1e18;
    uint256 _directDecimals = 18;
    uint256 _inverseDecimals = 6;
    uint256 _pricingCurrency = uint32(uint160(JBConstants.NATIVE_TOKEN));
    uint256 _unitCurrency = uint32(uint160(makeAddr("someToken")));

    function setUp() public {
        super.pricesSetup();
    }

    modifier givenDirectFeedExists() {
        // Find the storage slot
        bytes32 priceFeedForSlot = keccak256(abi.encode(_projectId, uint256(1)));
        bytes32 pricingSlot = keccak256(abi.encode(_pricingCurrency, uint256(priceFeedForSlot)));
        bytes32 slot = keccak256(abi.encode(_unitCurrency, uint256(pricingSlot)));

        bytes32 feedBytes = bytes32(uint256(uint160(address(_feed))));

        // Set direct price feed
        vm.store(address(_prices), slot, feedBytes);

        // Confirm price feed was set
        IJBPriceFeed feed = _prices.priceFeedFor(_projectId, _pricingCurrency, _unitCurrency);
        assertEq(address(feed), address(_feed));

        bytes memory currentUnitPriceCall = abi.encodeCall(IJBPriceFeed.currentUnitPrice, (_inverseDecimals));
        bytes memory directReturned = abi.encode(_directPrice);

        mockExpect(address(feed), currentUnitPriceCall, directReturned);
        _;
    }

    modifier givenIndirectFeedExists() {
        // Find the storage slot
        bytes32 priceFeedForSlot = keccak256(abi.encode(_projectId, uint256(1)));
        bytes32 pricingSlot = keccak256(abi.encode(_unitCurrency, uint256(priceFeedForSlot)));
        bytes32 slot = keccak256(abi.encode(_pricingCurrency, uint256(pricingSlot)));

        bytes32 feedBytes = bytes32(uint256(uint160(address(_feed))));

        // Set indirect price feed
        vm.store(address(_prices), slot, feedBytes);

        // Confirm price feed was set
        IJBPriceFeed feed = _prices.priceFeedFor(_projectId, _unitCurrency, _pricingCurrency);
        assertEq(address(feed), address(_feed));

        bytes memory currentUnitPriceCall = abi.encodeCall(IJBPriceFeed.currentUnitPrice, (_directDecimals));
        bytes memory directReturned = abi.encode(_inversePrice);

        mockExpect(address(feed), currentUnitPriceCall, directReturned);
        _;
    }

    modifier givenOnlyDefaultDirectFeedExists() {
        // Find the storage slot
        bytes32 priceFeedForSlot = keccak256(abi.encode(DEFAULT_PROJECT_ID, uint256(1)));
        bytes32 pricingSlot = keccak256(abi.encode(_pricingCurrency, uint256(priceFeedForSlot)));
        bytes32 slot = keccak256(abi.encode(_unitCurrency, uint256(pricingSlot)));

        bytes32 feedBytes = bytes32(uint256(uint160(address(_feed))));

        // Set direct price feed
        vm.store(address(_prices), slot, feedBytes);

        // Confirm price feed was set
        IJBPriceFeed feed = _prices.priceFeedFor(DEFAULT_PROJECT_ID, _pricingCurrency, _unitCurrency);
        assertEq(address(feed), address(_feed));

        bytes memory currentUnitPriceCall = abi.encodeCall(IJBPriceFeed.currentUnitPrice, (_inverseDecimals));
        bytes memory directReturned = abi.encode(_defaultDirectPrice);

        mockExpect(address(feed), currentUnitPriceCall, directReturned);
        _;
    }

    function test_WhenPricingCurrencyIsTheSameAsUnitCurrency() external {
        // it should return 1 with requested decimals

        uint256 price = _prices.pricePerUnitOf(_projectId, _pricingCurrency, _pricingCurrency, 18);
        assertEq(price, 1e18);
    }

    function test_WhenPriceFeedExistsForProjectIdAndPricingCurrencyToUnitCurrency() external givenDirectFeedExists {
        // it should return the current price from price feed

        uint256 pricesPrice = _prices.pricePerUnitOf(_projectId, _pricingCurrency, _unitCurrency, 6);
        assertEq(pricesPrice, _directPrice);
    }

    function test_WhenInversePriceFeedExistsForProjectIdAndUnitCurrencyToPricingCurrency()
        external
        givenIndirectFeedExists
    {
        // it should return the inverse of the current price from inverse price feed

        uint256 inversePrice = _prices.pricePerUnitOf(_projectId, _pricingCurrency, _unitCurrency, 18);
        assertEq(inversePrice, _inversePrice);
    }

    function test_WhenProjectIdIsNotTheDEFAULT_PROJECT_IDAndNoDirectOrInversePriceFeedIsFound()
        external
        givenOnlyDefaultDirectFeedExists
    {
        // it should attempt to use the default price feed for DEFAULT_PROJECT_ID

        uint256 defaultPrice = _prices.pricePerUnitOf(_projectId, _pricingCurrency, _unitCurrency, 6);
        assertEq(defaultPrice, _defaultDirectPrice);
    }

    function test_WhenNoPriceFeedIsFoundOrExistsIncludingDefaultCase() external {
        // it should revert with PRICE_FEED_NOT_FOUND

        vm.expectRevert(abi.encodeWithSignature("PRICE_FEED_NOT_FOUND()"));
        _prices.pricePerUnitOf(_projectId, _pricingCurrency, _unitCurrency, 6);
    }
}
