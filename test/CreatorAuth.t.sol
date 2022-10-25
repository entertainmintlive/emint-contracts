// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./EmintTest.t.sol";
import "../src/CreatorAuth.sol";
import "../src/interfaces/ICommonErrors.sol";

contract CreatorAuthTest is EmintTest {
    CreatorAuth internal creatorAuth;

    address alice = mkaddr("alice");
    address bob = mkaddr("bob");
    address carol = mkaddr("carol");
    address eve = mkaddr("eve");

    address controller = mkaddr("controller");

    event Allow(address caller);
    event Deny(address caller);

    function setUp() public {
        creatorAuth = new CreatorAuth(controller);
    }
}

contract TestController is CreatorAuthTest {
    function test_has_controller_address() public {
        assertEq(creatorAuth.controller(), controller);
    }

    function test_controller_can_allow_creator() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        assertEq(creatorAuth.allowed(alice), true);
    }

    function test_non_controller_cannot_allow_creator() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creatorAuth.allow(alice);
    }

    function test_allow_creator_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit Allow(alice);

        vm.prank(controller);
        creatorAuth.allow(alice);
    }

    function test_controller_can_deny_creator() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        assertEq(creatorAuth.allowed(alice), true);

        vm.prank(controller);
        creatorAuth.deny(alice);

        assertEq(creatorAuth.allowed(alice), false);
    }

    function test_non_controller_cannot_deny_creator() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creatorAuth.deny(alice);
    }

    function test_deny_creator_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit Deny(eve);

        vm.prank(controller);
        creatorAuth.deny(eve);
    }

    function test_multiple_allow_deny() public {
        vm.startPrank(controller);
        creatorAuth.allow(alice);
        creatorAuth.allow(bob);
        creatorAuth.allow(carol);
        creatorAuth.deny(eve);
        creatorAuth.deny(alice);
        vm.stopPrank();

        assertEq(creatorAuth.allowed(alice), false);
        assertEq(creatorAuth.allowed(bob), true);
        assertEq(creatorAuth.allowed(carol), true);
        assertEq(creatorAuth.allowed(eve), false);
    }
}

contract TestContractInfo is CreatorAuthTest {
    function test_has_name() public {
        assertEq(creatorAuth.NAME(), "CreatorAuth");
    }

    function test_has_version() public {
        assertEq(creatorAuth.VERSION(), "0.0.1");
    }
}
