// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

contract TestPermissions_Local is TestBaseWorkflow {
    IJBController private _controller;
    JBRulesetMetadata private _metadata;
    IJBTerminal private _terminal;
    IJBPermissions private _permissions;

    address private _projectOwner;
    uint256 private _projectZero;
    uint256 private _projectOne;

    function setUp() public override {
        super.setUp();

        _projectOwner = multisig();
        _terminal = jbMultiTerminal();
        _controller = jbController();
        _permissions = jbPermissions();

        _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            allowControllerMigration: false,
            allowSetController: false,
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
        _rulesetConfig[0].weight = 0;
        _rulesetConfig[0].decayRate = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = new JBFundAccessLimitGroup[](0);

        // Package up terminal configuration.
        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        address[] memory _tokensToAccept = new address[](1);
        _tokensToAccept[0] = JBConstants.NATIVE_TOKEN;
        _terminalConfigurations[0] = JBTerminalConfig({terminal: _terminal, tokensToAccept: _tokensToAccept});

        _projectZero = _controller.launchProjectFor({
            owner: makeAddr("zeroOwner"),
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        _projectOne = _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });
    }

    function testFailMostBasicAccess() public {
        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = 0;
        _rulesetConfig[0].decayRate = 0;
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

        uint256[] memory permIds = new uint256[](257);

        // Push an index higher than 255.
        for (uint256 i; i < 257; i++) {
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

        uint256[] memory permIds = new uint256[](256);

        // Push an index higher than 255.
        for (uint256 i; i < 256; i++) {
            permIds[i] = i;

            permData[0] = JBPermissionsData({operator: address(0), projectId: _projectOne, permissionIds: permIds});

            // Set em.
            vm.prank(_projectOwner);
            _permissions.setPermissionsFor(_projectOwner, permData[0]);

            // Verify.
            bool _check = _permissions.hasPermission(address(0), _projectOwner, _projectOne, permIds[i]);
            assertEq(_check, true);
        }
    }

    function testHasPermissions(
        address _account,
        address _operator,
        uint256 _projectId,
        uint8[] memory _u8_check_permissions,
        uint8[] memory _u8_set_permissions
    )
        public
    {
        uint256[] memory _check_permissions = new uint256[](_u8_check_permissions.length);
        uint256[] memory _set_permissions = new uint256[](_u8_set_permissions.length);

        // Check if all the items in `check_permissions` also exist in `set_permissions`.
        bool _shouldHavePermissions = true;
        for (uint256 _i; _i < _u8_check_permissions.length; _i++) {
            bool _exists;
            _check_permissions[_i] = _u8_check_permissions[_i];
            for (uint256 _j; _j < _u8_set_permissions.length; _j++) {
                // We update this lots of times unnecesarily but no need to optimize this.
                _set_permissions[_j] = _u8_set_permissions[_j];
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

        // Set the permissions.
        vm.prank(_account);
        _permissions.setPermissionsFor(
            _account, JBPermissionsData({operator: _operator, projectId: _projectId, permissionIds: _set_permissions})
        );

        assertEq(
            _permissions.hasPermissions(_operator, _account, _projectId, _check_permissions), _shouldHavePermissions
        );
    }

    /* function testBasicAccessSetup() public {
        vm.prank(address(_projectOwner));
        bool _check = _permissions.hasPermission(address(_projectOwner), address(_projectOwner), 0, 2);

        assertEq(_check, true);
    } */
}
