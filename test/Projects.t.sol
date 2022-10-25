// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./EmintTest.t.sol";
import "../src/Projects.sol";
import "../src/interfaces/ICommonErrors.sol";

contract ProjectsTest is EmintTest {
    Projects internal projects;

    address alice = mkaddr("alice");
    address bob = mkaddr("bob");

    address creators = mkaddr("creators");
    address controller = mkaddr("controller");

    event CreateProject(uint32 id);

    function setUp() public {
        projects = new Projects(controller);

        vm.prank(controller);
        projects.allow(creators);
    }
}

contract TestCreateProject is ProjectsTest {
    function test_can_create_new_project() public {
        vm.prank(creators);
        projects.create(alice);

        assertEq(projects.ownerOf(1), alice);
    }

    function test_create_new_project_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit CreateProject(1);

        vm.prank(creators);
        projects.create(alice);
    }

    function test_owner_of_reverts_if_owner_does_not_exist() public {
        vm.expectRevert(ICommonErrors.NotFound.selector);
        projects.ownerOf(1);
    }

    function test_exists_returns_true_if_project_exists() public {
        vm.prank(creators);
        projects.create(alice);

        assertEq(projects.exists(1), true);
    }

    function test_exists_returns_false_if_project_does_not_exist() public {
        assertEq(projects.exists(1), false);
    }
}

contract TestTransferOwnership is ProjectsTest {
    event TransferOwnership(uint32 indexed projectId, address indexed owner, address indexed newOwner);
    event AcceptOwnership(uint32 indexed projectId, address indexed owner, address indexed newOwner);

    function test_can_propose_new_owner() public {
        vm.prank(creators);
        projects.create(alice);

        assertEq(projects.ownerOf(1), alice);

        vm.expectEmit(true, true, true, false);
        emit TransferOwnership(1, alice, bob);

        vm.prank(creators);
        projects.transferOwnership(1, bob);

        assertEq(projects.pendingOwnerOf(1), bob);
    }

    function test_can_accept_ownership() public {
        vm.prank(creators);
        projects.create(alice);

        assertEq(projects.ownerOf(1), alice);

        vm.expectEmit(true, true, true, false);
        emit TransferOwnership(1, alice, bob);

        vm.prank(creators);
        projects.transferOwnership(1, bob);

        vm.prank(creators);
        assertEq(projects.pendingOwnerOf(1), bob);

        vm.expectEmit(true, true, true, false);
        emit AcceptOwnership(1, alice, bob);

        vm.prank(creators);
        projects.acceptOwnership(1);

        vm.expectRevert(ICommonErrors.NotFound.selector);
        projects.pendingOwnerOf(1);

        assertEq(projects.ownerOf(1), bob);
    }
}

contract TestPause is ProjectsTest {
    function test_is_not_paused_by_default() public {
        assertEq(projects.paused(), false);
    }

    function test_can_be_paused_by_controller() public {
        vm.prank(controller);
        projects.pause();

        assertEq(projects.paused(), true);
    }

    function test_cannot_be_paused_by_non_controller() public {
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        projects.pause();

        assertEq(projects.paused(), false);
    }

    function test_can_be_unpaused_by_controller() public {
        vm.prank(controller);
        projects.pause();

        assertEq(projects.paused(), true);

        vm.prank(controller);
        projects.unpause();

        assertEq(projects.paused(), false);
    }

    function test_cannot_be_unpaused_by_non_controller() public {
        vm.prank(controller);
        projects.pause();

        assertEq(projects.paused(), true);

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        projects.unpause();

        assertEq(projects.paused(), true);
    }

    function test_cannot_create_project_when_paused() public {
        vm.prank(controller);
        projects.pause();

        vm.prank(creators);
        vm.expectRevert("Pausable: paused");
        projects.create(alice);
    }
}
