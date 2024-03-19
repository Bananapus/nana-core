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

        // mock ownerOf call
        bytes memory projectsOwnerCall = abi.encodeCall(IERC721.ownerOf, (0));
        bytes memory returned = abi.encode(address(this));

        mockExpect(address(projects), projectsOwnerCall, returned);

        _prices.addPriceFeedFor(DEFAULT_PROJECT_ID, _pricingCurrency, _unitCurrency, _feed);
    }

    modifier whenProjectIsNotDefaultAndHasPermissions() {
        // mock ownerOf call
        bytes memory projectsOwnerCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory returned = abi.encode(_projectOneOwner);

        mockExpect(address(projects), projectsOwnerCall, returned);

        // mock hasPermissions call
        bytes memory permissionsCall = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), _projectOneOwner, _projectId, JBPermissionIds.ADD_PRICE_FEED)
        );
        bytes memory returned2 = abi.encode(true);

        mockExpect(address(permissions), permissionsCall, returned2);
        _;
    }

    function test_WhenProjectIdIsNotTheDEFAULT_PROJECT_ID() external whenProjectIsNotDefaultAndHasPermissions {
        // it should require ADD_PRICE_FEED permission from the project's owner or an operator

        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _unitCurrency, _feed);
    }

    function test_WhenPricingCurrencyOrUnitCurrencyIs0() external whenProjectIsNotDefaultAndHasPermissions {
        // it should revert with INVALID_CURRENCY

        vm.expectRevert(abi.encodeWithSignature("INVALID_CURRENCY()"));
        _prices.addPriceFeedFor(_projectId, _invalidCurrency, _unitCurrency, _feed);

        vm.expectRevert(abi.encodeWithSignature("INVALID_CURRENCY()"));
        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _invalidCurrency, _feed);
    }

    function test_WhenADefaultFeedForTheCurrencyPairOrItsInverseAlreadyExists()
        external
        whenProjectIsNotDefaultAndHasPermissions
    {
        // it should revert with PRICE_FEED_ALREADY_EXISTS

        vm.prank(_owner);
        _prices.addPriceFeedFor(DEFAULT_PROJECT_ID, _pricingCurrency, _unitCurrency, _feed);

        vm.expectRevert(abi.encodeWithSignature("PRICE_FEED_ALREADY_EXISTS()"));
        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _unitCurrency, _feed);
    }

    function test_WhenThisProjectAlreadyHasFeedsForTheCurrencyPairOrItsInverse()
        external
        whenProjectIsNotDefaultAndHasPermissions
    {
        // it should revert with PRICE_FEED_ALREADY_EXISTS

        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _unitCurrency, _feed);

        vm.expectRevert(abi.encodeWithSignature("PRICE_FEED_ALREADY_EXISTS()"));
        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _unitCurrency, _feed);
    }

    function test_HappyPath() external whenProjectIsNotDefaultAndHasPermissions {
        // it should store the feed for the project and currency pair
        // it should emit AddPriceFeed event with projectId, pricingCurrency, unitCurrency, and feed

        vm.expectEmit();
        emit IJBPrices.AddPriceFeed(_projectId, _pricingCurrency, _unitCurrency, _feed);

        _prices.addPriceFeedFor(_projectId, _pricingCurrency, _unitCurrency, _feed);
    }
}
