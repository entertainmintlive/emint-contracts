// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./EmintTest.t.sol";
import "../src/TokenAuth.sol";
import "../src/interfaces/ICommonErrors.sol";

contract TokenAuthTest is EmintTest {
    TokenAuth internal tokenAuth;

    address allowedToken = mkaddr("allowed token");
    address deniedToken = mkaddr("denied token");
    address eve = mkaddr("eve");

    address controller = mkaddr("controller");

    event Allow(address token);
    event Deny(address token);

    function setUp() public {
        tokenAuth = new TokenAuth(controller);
    }
}

contract TestController is TokenAuthTest {
    function test_has_controller_address() public {
        assertEq(tokenAuth.controller(), controller);
    }

    function test_controller_can_allow_token() public {
        vm.prank(controller);
        tokenAuth.allow(allowedToken);

        assertEq(tokenAuth.allowed(allowedToken), true);
    }

    function test_non_controller_cannot_allow_token() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokenAuth.allow(allowedToken);
    }

    function test_allow_token_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit Allow(allowedToken);

        vm.prank(controller);
        tokenAuth.allow(allowedToken);
    }

    function test_controller_can_deny_token() public {
        vm.prank(controller);
        tokenAuth.allow(allowedToken);

        assertEq(tokenAuth.allowed(allowedToken), true);

        vm.prank(controller);
        tokenAuth.deny(allowedToken);

        assertEq(tokenAuth.allowed(allowedToken), false);
    }

    function test_non_controller_cannot_deny_token() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokenAuth.deny(allowedToken);
    }

    function test_deny_token_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit Deny(deniedToken);

        vm.prank(controller);
        tokenAuth.deny(deniedToken);
    }
}

contract TestContractInfo is TokenAuthTest {
    function test_has_name() public {
        assertEq(tokenAuth.NAME(), "TokenAuth");
    }

    function test_has_version() public {
        assertEq(tokenAuth.VERSION(), "0.0.1");
    }
}
