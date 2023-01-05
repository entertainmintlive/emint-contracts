// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./EmintTest.t.sol";

import "../src/Tokens.sol";
import "../src/TokenDeployer.sol";
import "../src/interfaces/ICommonErrors.sol";

contract TokenDeployerTest is EmintTest {
    Tokens internal tokens;
    TokenDeployer internal deployer;

    address alice = mkaddr("alice");
    address bob = mkaddr("bob");
    address carol = mkaddr("carol");
    address eve = mkaddr("eve");

    address controller = mkaddr("controller");
    address metadata = mkaddr("metadata");
    address royalties = mkaddr("royalties");

    event Allow(address caller);
    event Deny(address caller);

    function setUp() public {
        tokens = new Tokens(controller);
        deployer = new TokenDeployer(controller);

        vm.startPrank(controller);
        deployer.setDependency("tokens", address(tokens));

        tokens.setDependency("deployer", address(deployer));
        tokens.setDependency("metadata", metadata);
        tokens.setDependency("royalties", royalties);
        vm.stopPrank();
    }
}

contract TestDeployment is TokenDeployerTest {
    function test_has_tokens_address() public {
        assertEq(deployer.tokens(), address(tokens));
    }

    function test_allowed_address_can_deploy_token() public {
        vm.prank(controller);
        deployer.allow(address(this));

        address token = deployer.deploy();
        deployer.register(1, token);

        assertEq(address(tokens.token(1)), token);
    }

    function test_denied_address_cannot_deploy_token() public {
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        deployer.deploy();
    }

    function test_denied_address_cannot_register_token() public {
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        deployer.register(1, address(0));
    }
}

contract TestController is TokenDeployerTest {
    event SetTokens(address oldTokens, address newTokens);

    function test_has_controller_address() public {
        assertEq(deployer.controller(), controller);
    }

    function test_controller_can_allow_deployer() public {
        vm.prank(controller);
        deployer.allow(alice);

        assertEq(deployer.allowed(alice), true);
    }

    function test_non_controller_cannot_allow_deployer() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        deployer.allow(alice);
    }

    function test_allow_deployer_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit Allow(alice);

        vm.prank(controller);
        deployer.allow(alice);
    }

    function test_controller_can_deny_deployer() public {
        vm.prank(controller);
        deployer.allow(alice);

        assertEq(deployer.allowed(alice), true);

        vm.prank(controller);
        deployer.deny(alice);

        assertEq(deployer.allowed(alice), false);
    }

    function test_non_controller_cannot_deny_deployer() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        deployer.deny(alice);
    }

    function test_deny_deployer_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit Deny(eve);

        vm.prank(controller);
        deployer.deny(eve);
    }

    function test_multiple_allow_deny() public {
        vm.startPrank(controller);
        deployer.allow(alice);
        deployer.allow(bob);
        deployer.allow(carol);
        deployer.deny(eve);
        deployer.deny(alice);
        vm.stopPrank();

        assertEq(deployer.allowed(alice), false);
        assertEq(deployer.allowed(bob), true);
        assertEq(deployer.allowed(carol), true);
        assertEq(deployer.allowed(eve), false);
    }

    function test_controller_can_set_new_tokens() public {
        address newTokens = mkaddr("new reciever");

        vm.prank(controller);
        deployer.setDependency("tokens", newTokens);

        assertEq(deployer.tokens(), newTokens);
    }

    function test_set_tokens_emits_event() public {
        address newTokens = mkaddr("new reciever");

        vm.expectEmit(false, false, false, true);
        emit SetTokens(address(tokens), newTokens);

        vm.prank(controller);
        deployer.setDependency("tokens", newTokens);
    }

    function test_non_controller_cannot_set_new_tokens() public {
        address newTokens = mkaddr("new reciever");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        deployer.setDependency("tokens", newTokens);
    }

    function test_controller_cannot_set_invalid_dependency() public {
        address invalid = mkaddr("invalid");

        vm.expectRevert(abi.encodeWithSelector(IControllable.InvalidDependency.selector, bytes32("invalid")));
        vm.prank(controller);
        deployer.setDependency("invalid", invalid);
    }

    function test_controller_cannot_set_zero_address() public {
        vm.expectRevert(ICommonErrors.ZeroAddress.selector);
        vm.prank(controller);
        deployer.setDependency("tokens", address(0));
    }
}

contract TestContractInfo is TokenDeployerTest {
    function test_has_name() public {
        assertEq(deployer.NAME(), "TokenDeployer");
    }

    function test_has_version() public {
        assertEq(deployer.VERSION(), "0.0.1");
    }
}
