// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

contract TestDelegates_Local is TestBaseWorkflow {
    JBController controller;
    JBProjectMetadata _projectMetadata;
    JBFundingCycleData _data;
    JBFundingCycleMetadata _metadata;
    JBGroupedSplits[] _groupedSplits;
    JBFundAccessConstraints[] _fundAccessConstraints;
    IJBPaymentTerminal[] _terminals;
    JBTokenStore _tokenStore;

    address _projectOwner;
    address _datasource = address(bytes20(keccak256("datasource")));

    uint256 _projectId;

    uint256 WEIGHT = 1000 * 10 ** 18;

    function setUp() public override {
        super.setUp();

        _projectOwner = multisig();

        _tokenStore = jbTokenStore();

        controller = jbController();

        _projectMetadata = JBProjectMetadata({content: "myIPFSHash", domain: 1});

        _data = JBFundingCycleData({
            duration: 14,
            weight: WEIGHT,
            discountRate: 450000000,
            ballot: IJBFundingCycleBallot(address(0))
        });

        _metadata = JBFundingCycleMetadata({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 5000, //50%
            redemptionRate: 5000, //50%
            ballotRedemptionRate: 0,
            pausePay: false,
            pauseDistributions: false,
            pauseRedeem: false,
            pauseBurn: false,
            allowMinting: false,
            allowTerminalMigration: false,
            allowControllerMigration: false,
            holdFees: false,
            preferClaimedTokenOverride: false,
            useTotalOverflowForRedemptions: false,
            useDataSourceForPay: true,
            useDataSourceForRedeem: true,
            dataSource: _datasource,
            metadata: 0
        });

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        _terminals.push(jbETHPaymentTerminal());
        _projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );
    }

    function testPayDelegates(uint256 _numberOfAllocations, uint256 _totalToAllocate) public {
        _numberOfAllocations = bound(_numberOfAllocations, 1, 5);

        JBPayDelegateAllocation[] memory _allocations = new JBPayDelegateAllocation[](_numberOfAllocations);
        uint256[] memory payDelegateAmounts = new uint256[](_numberOfAllocations);

        _beneficiary = address(bytes20(keccak256("beneficiary")));


        // Check that we are not going to overflow uint256 and calculate the total pay amount
        _totalToAllocate = bound(_totalToAllocate, payDelegateAmounts.length, type(uint256).max - 1);
        uint256 _paySum = _totalToAllocate;

        // Allocate descending amounts (by half)
        for (uint256 i ; i < payDelegateAmounts.length - 1; i++) {
            payDelegateAmounts[i] = _totalToAllocate / (payDelegateAmounts.length * 2);
            _totalToAllocate -= payDelegateAmounts[i];
        }

        // Rest to allocate into the last allocations
        payDelegateAmounts[payDelegateAmounts.length - 1] = _totalToAllocate;

        (JBFundingCycle memory fundingCycle, ) =
            controller.currentFundingCycleOf(_projectId);
        for (uint256 i = 0; i < payDelegateAmounts.length; i++) {
            address _delegateAddress = address(bytes20(keccak256(abi.encodePacked("PayDelegate", i))));

            _allocations[i] = JBPayDelegateAllocation(IJBPayDelegate(_delegateAddress), payDelegateAmounts[i]);

            JBDidPayData memory _didPayData = JBDidPayData(
                _beneficiary,
                _projectId,
                fundingCycle.configuration,
                JBTokenAmount(
                    JBTokens.ETH,
                    _paySum,
                    JBSingleTokenPaymentTerminal(address(_terminals[0])).decimals(),
                    JBSingleTokenPaymentTerminal(address(_terminals[0])).currency()
                ),
                JBTokenAmount(
                    JBTokens.ETH,
                    payDelegateAmounts[i],
                    JBSingleTokenPaymentTerminal(address(_terminals[0])).decimals(),
                    JBSingleTokenPaymentTerminal(address(_terminals[0])).currency()
                ),
                0,
                _beneficiary,
                false,
                "",
                new bytes(0) // empty metadata
            );

            // Mock the delegate
            vm.mockCall(_delegateAddress, abi.encodeWithSelector(IJBPayDelegate.didPay.selector), "");

            // Assert that the delegate gets called with the expected value
            vm.expectCall(
                _delegateAddress, payDelegateAmounts[i], abi.encodeWithSelector(IJBPayDelegate.didPay.selector, _didPayData)
            );

            // Expect an event to be emitted for every delegate
            vm.expectEmit(true, true, true, true);
            emit DelegateDidPay(IJBPayDelegate(_delegateAddress), _didPayData, payDelegateAmounts[i], _beneficiary);
        }

        vm.mockCall(
            _datasource,
            abi.encodeWithSelector(IJBFundingCycleDataSource.payParams.selector),
            abi.encode(
                0, // weight
                "", // memo
                _allocations // allocations
            )
        );

        vm.deal(_beneficiary, _paySum);
        vm.prank(_beneficiary);
        _terminals[0].pay{value: _paySum}(
            _projectId, _paySum, address(0), _beneficiary, 0, false, "Forge test", new bytes(0)
        );
    }

    event DelegateDidPay(IJBPayDelegate indexed delegate, JBDidPayData data, uint256 delegatedAmount, address caller);
}
