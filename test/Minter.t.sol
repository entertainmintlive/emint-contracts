// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "./EmintTest.t.sol";
import "../src/Tokens.sol";
import "../src/Minter.sol";
import "../src/interfaces/ICommonErrors.sol";

contract MinterTest is EmintTest, ERC1155Holder {
    Tokens internal tokens;
    Minter internal minter;

    address alice = mkaddr("alice");
    address bob = mkaddr("bob");
    address carol = mkaddr("carol");
    address eve = mkaddr("eve");

    address controller = mkaddr("controller");
    address deployer = mkaddr("deployer");
    address metadata = mkaddr("metadata");
    address royalties = mkaddr("royalties");

    event Allow(address caller);
    event Deny(address caller);

    function setUp() public {
        tokens = new Tokens(controller);
        minter = new Minter(controller);

        vm.startPrank(controller);
        minter.setDependency("tokens", address(tokens));

        tokens.setDependency("minter", address(minter));
        tokens.setDependency("deployer", deployer);
        tokens.setDependency("metadata", metadata);
        tokens.setDependency("royalties", royalties);
        vm.stopPrank();
    }
}

contract TestToken is MinterTest {
    function test_has_tokens_address() public {
        assertEq(minter.tokens(), address(tokens));
    }

    function test_allowed_address_can_mint_token() public {
        vm.prank(controller);
        minter.allow(address(this));

        vm.startPrank(deployer);
        address token = tokens.deploy();
        tokens.register(1, token);
        vm.stopPrank();

        minter.mint(address(this), 1, 1, "");

        assertEq(tokens.token(1).balanceOf(address(this), 1), 1);
    }

    function test_denied_address_cannot_mint_token() public {
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        minter.mint(address(this), 1, 1, "");
    }
}

contract TestController is MinterTest {
    function test_has_controller_address() public {
        assertEq(minter.controller(), controller);
    }

    function test_controller_can_allow_minter() public {
        vm.prank(controller);
        minter.allow(alice);

        assertEq(minter.allowed(alice), true);
    }

    function test_non_controller_cannot_allow_minter() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        minter.allow(alice);
    }

    function test_allow_minter_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit Allow(alice);

        vm.prank(controller);
        minter.allow(alice);
    }

    function test_controller_can_deny_minter() public {
        vm.prank(controller);
        minter.allow(alice);

        assertEq(minter.allowed(alice), true);

        vm.prank(controller);
        minter.deny(alice);

        assertEq(minter.allowed(alice), false);
    }

    function test_non_controller_cannot_deny_minter() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        minter.deny(alice);
    }

    function test_deny_minter_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit Deny(eve);

        vm.prank(controller);
        minter.deny(eve);
    }

    function test_multiple_allow_deny() public {
        vm.startPrank(controller);
        minter.allow(alice);
        minter.allow(bob);
        minter.allow(carol);
        minter.deny(eve);
        minter.deny(alice);
        vm.stopPrank();

        assertEq(minter.allowed(alice), false);
        assertEq(minter.allowed(bob), true);
        assertEq(minter.allowed(carol), true);
        assertEq(minter.allowed(eve), false);
    }
}

contract TestContractInfo is MinterTest {
    function test_has_name() public {
        assertEq(minter.NAME(), "Minter");
    }

    function test_has_version() public {
        assertEq(minter.VERSION(), "0.0.1");
    }
}
