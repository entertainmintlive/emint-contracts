// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./EmintTest.t.sol";
import "./fakes/FakePausable.sol";
import "./fakes/FakeAllowList.sol";
import "./fakes/FakeControllable.sol";
import "../src/Controller.sol";
import "../src/interfaces/ICommonErrors.sol";

contract ControllerTest is EmintTest {
    Controller internal controller;
    FakePausable internal pausable;
    FakeAllowList internal allowList;
    FakeControllable internal controllable;

    address alice = mkaddr("alice");
    address bob = mkaddr("bob");
    address carol = mkaddr("carol");
    address eve = mkaddr("eve");

    address dependency = mkaddr("dependency");

    function setUp() public {
        controller = new Controller();
        pausable = new FakePausable(address(controller));
        allowList = new FakeAllowList(address(controller));
        controllable = new FakeControllable(address(controller), dependency);
    }
}

contract TestOwnership is ControllerTest {
    function test_default_owner_is_deployer() public {
        assertEq(controller.owner(), address(this));
    }

    function test_ownership_transfer() public {
        assertEq(controller.pendingOwner(), address(0));

        controller.transferOwnership(alice);
        assertEq(controller.pendingOwner(), alice);

        vm.prank(alice);
        controller.acceptOwnership();

        assertEq(controller.pendingOwner(), address(0));
        assertEq(controller.owner(), alice);
    }
}

contract TestPausables is ControllerTest {
    event AllowPauser(address pauser);
    event DenyPauser(address pauser);

    function test_owner_can_pause() public {
        assertEq(pausable.paused(), false);

        controller.pause(address(pausable));

        assertEq(pausable.paused(), true);
    }

    function test_owner_can_add_pauser() public {
        assertEq(pausable.paused(), false);

        vm.expectEmit(false, false, false, true);
        emit AllowPauser(alice);

        controller.allowPauser(alice);
        assertEq(controller.pausers(alice), true);

        vm.prank(alice);
        controller.pause(address(pausable));

        assertEq(pausable.paused(), true);

        vm.prank(alice);
        controller.unpause(address(pausable));

        assertEq(pausable.paused(), false);
    }

    function test_owner_can_deny_pauser() public {
        assertEq(pausable.paused(), false);

        controller.allowPauser(alice);

        assertEq(controller.pausers(alice), true);

        vm.expectEmit(false, false, false, true);
        emit DenyPauser(alice);

        controller.denyPauser(alice);

        assertEq(controller.pausers(alice), false);

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        vm.prank(alice);
        controller.pause(address(pausable));
    }

    function test_non_pauser_cannot_pause() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        controller.pause(address(pausable));
    }

    function test_owner_can_unpause() public {
        controller.pause(address(pausable));

        assertEq(pausable.paused(), true);

        controller.unpause(address(pausable));

        assertEq(pausable.paused(), false);
    }

    function test_non_pauser_cannot_unpause() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        controller.unpause(address(pausable));
    }
}

contract TestAllowLists is ControllerTest {
    function test_owner_can_allow() public {
        assertEq(allowList.allowed(bob), false);

        controller.allow(address(allowList), bob);

        assertEq(allowList.allowed(bob), true);
    }

    function test_non_owner_cannot_allow() public {
        vm.prank(eve);
        vm.expectRevert("Ownable: caller is not the owner");
        controller.allow(address(allowList), eve);
    }

    function test_owner_can_deny() public {
        controller.allow(address(allowList), bob);

        assertEq(allowList.allowed(bob), true);

        controller.deny(address(allowList), bob);

        assertEq(allowList.allowed(bob), false);
        assertEq(allowList.denied(bob), true);
    }

    function test_non_owner_cannot_deny() public {
        vm.prank(eve);
        vm.expectRevert("Ownable: caller is not the owner");
        controller.deny(address(allowList), alice);
    }
}

contract TestDependencies is ControllerTest {
    function test_owner_can_set_valid_dependency() public {
        address newDependency = mkaddr("new dependency");

        assertEq(controllable.dependency(), dependency);

        controller.setDependency(address(controllable), "dependency", newDependency);

        assertEq(controllable.dependency(), newDependency);
    }

    function test_non_owner_cannot_set_dependency() public {
        vm.prank(eve);
        vm.expectRevert("Ownable: caller is not the owner");
        controller.setDependency(address(controllable), "dependency", address(0));
    }

    function test_invalid_dependency_reverts() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidDependency(bytes32)", bytes32("invalid")));
        controller.setDependency(address(controllable), "invalid", address(0));
    }
}

contract TestExec is ControllerTest {
    function test_owner_can_execute_call() public {
        assertEq(pausable.paused(), false);

        bytes memory callData = abi.encodeWithSignature("pause()");

        controller.exec(address(pausable), callData);

        assertEq(pausable.paused(), true);
    }

    function test_exec_reverts_on_failure() public {
        bytes memory callData = abi.encodeWithSignature("doesNotExist()");

        vm.expectRevert(abi.encodeWithSignature("ExecFailed(bytes)", ""));
        controller.exec(address(pausable), callData);
    }

    function test_non_owner_cannot_execute_call() public {
        bytes memory callData = abi.encodeWithSignature("pause()");

        vm.prank(eve);
        vm.expectRevert("Ownable: caller is not the owner");
        controller.exec(address(pausable), callData);
    }
}

contract TestContractInfo is ControllerTest {
    function test_has_name() public {
        assertEq(controller.NAME(), "Controller");
    }

    function test_has_version() public {
        assertEq(controller.VERSION(), "0.0.1");
    }
}
