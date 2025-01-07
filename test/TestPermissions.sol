// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

contract TestPermissions_Local is TestBaseWorkflow, JBTest {
    IJBController private _controller;
    JBRulesetMetadata private _metadata;
    IJBTerminal private _terminal;
    IJBPermissions private _permissions;

    address private _projectOwner;
    uint56 private _projectZero;
    uint56 private _projectOne;

    function setUp() public override {
        super.setUp();

        _projectOwner = multisig();
        _terminal = jbMultiTerminal();
        _controller = jbController();
        _permissions = jbPermissions();

        _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: true,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = 0;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = new JBFundAccessLimitGroup[](0);

        // Package up terminal configuration.
        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](1);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept});

        _projectZero = uint56(
            _controller.launchProjectFor({
                owner: makeAddr("zeroOwner"),
                projectUri: "myIPFSHash",
                rulesetConfigurations: _rulesetConfig,
                terminalConfigurations: _terminalConfigurations,
                memo: ""
            })
        );

        _projectOne = uint56(
            _controller.launchProjectFor({
                owner: _projectOwner,
                projectUri: "myIPFSHash",
                rulesetConfigurations: _rulesetConfig,
                terminalConfigurations: _terminalConfigurations,
                memo: ""
            })
        );
    }

    function testFailMostBasicAccess() public {
        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = 0;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = new JBFundAccessLimitGroup[](0);

        vm.prank(makeAddr("zeroOwner"));
        uint256 queued = _controller.queueRulesetsOf(_projectOne, _rulesetConfig, "");

        assertEq(queued, block.timestamp);
    }

    function testFailSetOperators() public {
        // Pack up our permission data.
        JBPermissionsData[] memory permData = new JBPermissionsData[](1);

        uint8[] memory permIds = new uint8[](257);

        // Push an index higher than 255.
        for (uint8 i; i < 257; i++) {
            permIds[i] = i;

            permData[0] = JBPermissionsData({operator: address(0), projectId: _projectOne, permissionIds: permIds});

            // Set em.
            vm.prank(_projectOwner);
            _permissions.setPermissionsFor(_projectOwner, permData[0]);
        }
    }

    function testSetOperators() public {
        // Pack up our permission data.
        JBPermissionsData[] memory permData = new JBPermissionsData[](1);

        uint8[] memory permIds = new uint8[](256);

        // Push an index higher than 255.
        for (uint256 i; i < 256; i++) {
            permIds[i] = uint8(i);

            permData[0] = JBPermissionsData({operator: address(0), projectId: _projectOne, permissionIds: permIds});

            // Set em.
            vm.prank(_projectOwner);
            _permissions.setPermissionsFor(_projectOwner, permData[0]);

            // Verify.
            bool _check = _permissions.hasPermission(address(0), _projectOwner, _projectOne, permIds[i], true, true);
            assertEq(_check, true);
        }
    }

    function testHasPermissions(
        address _account,
        address _operator,
        uint56 _projectId,
        uint8[] memory _u8_check_permissions,
        uint8[] memory _u8_set_permissions
    )
        public
    {
        uint256[] memory _check_permissions = new uint256[](_u8_check_permissions.length);
        uint8[] memory _set_permissions = new uint8[](_u8_set_permissions.length);

        // Check if all the items in `check_permissions` also exist in `set_permissions`.
        bool _shouldHavePermissions = true;
        bool _containsRoot;
        for (uint256 _i; _i < _u8_check_permissions.length; _i++) {
            bool _exists;
            _check_permissions[_i] = _u8_check_permissions[_i];
            for (uint256 _j; _j < _u8_set_permissions.length; _j++) {
                // We update this lots of times unnecesarily but no need to optimize this.
                _set_permissions[_j] = _u8_set_permissions[_j % 256];

                // Update if we find root value.
                if (_u8_set_permissions[_j] == 1) _containsRoot = true;

                // If we find this item we break and mark the flag.
                if (_u8_check_permissions[_i] == _u8_set_permissions[_j]) {
                    _exists = true;
                    break;
                }
            }

            // If any item does not exist we should not have permission.
            if (_exists == false) {
                _shouldHavePermissions = false;
                break;
            }
        }

        if (_containsRoot && _projectId == 0) {
            vm.expectRevert(JBPermissions.JBPermissions_CantSetRootPermissionForWildcardProject.selector);
        }

        // Set the permissions.
        vm.prank(_account);
        _permissions.setPermissionsFor(
            _account, JBPermissionsData({operator: _operator, projectId: _projectId, permissionIds: _set_permissions})
        );

        assertEq(
            _permissions.hasPermissions(_operator, _account, _projectId, _check_permissions, false, false),
            _shouldHavePermissions
        );
    }

    function testSetRootWildcardProjectId(address _account, address _operator) public {
        uint8[] memory _set_permissions = new uint8[](1);
        _set_permissions[0] = JBPermissionIds.ROOT;

        // Set the permissions.
        vm.prank(_account);

        vm.expectRevert(JBPermissions.JBPermissions_CantSetRootPermissionForWildcardProject.selector);
        _permissions.setPermissionsFor(
            _account,
            JBPermissionsData({operator: _operator, projectId: 0, /* wildcard */ permissionIds: _set_permissions})
        );
    }

    function testBasicAccessSetup() public {
        address zeroOwner = makeAddr("zeroOwner");
        address token = address(usdcToken());

        // Pack up our permission data.
        JBPermissionsData[] memory permData = new JBPermissionsData[](1);
        uint8[] memory permIds = new uint8[](1);
        permIds[0] = 1;

        permData[0] = JBPermissionsData({operator: address(this), projectId: _projectZero, permissionIds: permIds});

        // Set em.
        vm.prank(zeroOwner);
        _permissions.setPermissionsFor(zeroOwner, permData[0]);

        // Should be true given root check
        bool _check = _permissions.hasPermission(address(this), zeroOwner, _projectZero, 2, true, true);
        assertEq(_check, true);

        // Will revert attempting to set another projects token
        vm.expectRevert(
            abi.encodeWithSelector(
                JBPermissioned.JBPermissioned_Unauthorized.selector, _projectOwner, address(this), 2, 8
            )
        );
        _controller.setTokenFor(2, IJBToken(token));

        // Will succeed when setting the correct projects token
        mockExpect(token, abi.encodeCall(MockERC20.decimals, ()), abi.encode(18));
        _controller.setTokenFor(1, IJBToken(token));
    }

    function testCannotForwardRoot() public {
        address zeroOwner = makeAddr("zeroOwner");

        // Pack up our permission data.
        JBPermissionsData[] memory permData = new JBPermissionsData[](1);
        uint8[] memory permIds = new uint8[](1);
        permIds[0] = 1;

        permData[0] = JBPermissionsData({operator: address(this), projectId: _projectZero, permissionIds: permIds});

        // Set em.
        vm.prank(zeroOwner);
        _permissions.setPermissionsFor(zeroOwner, permData[0]);

        // Should be true given root check
        bool _check = _permissions.hasPermission(address(this), zeroOwner, _projectZero, 2, true, true);
        assertEq(_check, true);

        // Pack up our non-root permission data.
        JBPermissionsData[] memory permData2 = new JBPermissionsData[](1);
        uint8[] memory permIds2 = new uint8[](1);
        permIds2[0] = 2;

        permData2[0] = JBPermissionsData({operator: address(0), projectId: _projectZero, permissionIds: permIds2});

        // Should be able to forward other permissions
        // Note that this contract is now authorized to do so above- address(this)

        // in emit
        uint256 packed;

        vm.expectEmit();
        emit IJBPermissions.OperatorPermissionsSet(
            permData2[0].operator,
            zeroOwner,
            permData2[0].projectId,
            permData2[0].permissionIds,
            packed |= 1 << 2,
            address(this)
        );
        _permissions.setPermissionsFor(zeroOwner, permData2[0]);

        // Change the permission being set back to root
        permData2[0] = JBPermissionsData({operator: address(0), projectId: _projectZero, permissionIds: permIds});

        // Shouldn't be able to forward root
        vm.expectRevert(JBPermissions.JBPermissions_Unauthorized.selector);
        _permissions.setPermissionsFor(zeroOwner, permData2[0]);
    }
}
