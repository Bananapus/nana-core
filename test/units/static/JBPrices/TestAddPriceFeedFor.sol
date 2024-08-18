// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBPricesSetup} from "./JBPricesSetup.sol";

contract TestAddPriceFeedFor_Local is JBPricesSetup {
    IJBPriceFeed _feed = IJBPriceFeed(makeAddr("feed"));
    uint256 DEFAULT_PROJECT_ID = 0;
    uint256 _projectId = 1;
    address _projectOneOwner = makeAddr("oneOwner");
    uint256 _pricingCurrency = uint32(uint160(JBConstants.NATIVE_TOKEN));
    uint256 _unitCurrency = uint32(uint160(makeAddr("someToken")));
    uint256 _invalidCurrency = 0;

    function setUp() public {
        super.pricesSetup();
    }

    function test_WhenProjectIdIsTheDEFAULT_PROJECT_IDAndMsgSenderIsTheOwnerOfJBPrices() external {
        // it should add the price feed without checking permissions

        vm.prank(_owner);
        _prices.addPriceFeedFor(DEFAULT_PROJECT_ID, _pricingCurrency, _unitCurrency, _feed);
    }

    function test_WhenProjectIdIsTheDEFAULT_PROJECT_IDAndMsgSenderIsTheOwnerOfProjectZero() external {
        // it should add the price feed
        vm.prank(_owner);
        _prices.addPriceFeedFor(DEFAULT_PROJECT_ID, _pricingCurrency, _unitCurrency, _feed);
    }

    function test_WhenProjectIdIsTheDEFAULT_PROJECT_IDAndMsgSenderIsNotTheOwnerOfProjectZero() external {
        // it should revert ONLY_OWNER()

        // encode custom error
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        bytes memory expectedError = abi.encodeWithSelector(selector, address(this));

        vm.expectRevert(expectedError);
        _prices.addPriceFeedFor(DEFAULT_PROJECT_ID, _pricingCurrency, _unitCurrency, _feed);
    }

    modifier whenProjectIsNotDefaultAndHasPermissions() {
        // mock controllerOf call
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );
        _;
    }

    function test_WhenProjectIdIsNotTheDEFAULT_PROJECT_ID() external whenProjectIsNotDefaultAndHasPermissions {
        // it should require ADD_PRICE_FEED permission from the project's owner or an operator

        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _unitCurrency, _feed);
    }

    function test_WhenPricingCurrencyOrUnitCurrencyIs0() external whenProjectIsNotDefaultAndHasPermissions {
        // it should revert with INVALID_CURRENCY

        vm.expectRevert(JBPrices.JBPrices_InvalidCurrency.selector);
        _prices.addPriceFeedFor(_projectId, _invalidCurrency, _unitCurrency, _feed);

        vm.expectRevert(JBPrices.JBPrices_InvalidCurrency.selector);
        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _invalidCurrency, _feed);
    }

    function test_WhenADefaultFeedForTheCurrencyPairOrItsInverseAlreadyExists()
        external
        whenProjectIsNotDefaultAndHasPermissions
    {
        // it should revert with PRICE_FEED_ALREADY_EXISTS

        vm.prank(_owner);
        _prices.addPriceFeedFor(DEFAULT_PROJECT_ID, _pricingCurrency, _unitCurrency, _feed);

        vm.expectRevert(JBPrices.JBPrices_PriceFeedAlreadyExists.selector);
        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _unitCurrency, _feed);
    }

    function test_WhenThisProjectAlreadyHasFeedsForTheCurrencyPairOrItsInverse()
        external
        whenProjectIsNotDefaultAndHasPermissions
    {
        // it should revert with PRICE_FEED_ALREADY_EXISTS

        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _unitCurrency, _feed);

        vm.expectRevert(JBPrices.JBPrices_PriceFeedAlreadyExists.selector);
        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _unitCurrency, _feed);
    }

    function test_HappyPath() external whenProjectIsNotDefaultAndHasPermissions {
        // it should store the feed for the project and currency pair
        // it should emit AddPriceFeed event with projectId, pricingCurrency, unitCurrency, and feed

        vm.expectEmit();
        emit IJBPrices.AddPriceFeed(_projectId, _pricingCurrency, _unitCurrency, _feed, address(this));

        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _unitCurrency, _feed);
    }
}
