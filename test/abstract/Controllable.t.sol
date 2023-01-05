// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../EmintTest.t.sol";
import "../../src/abstract/Controllable.sol";
import "../../src/Controller.sol";

contract EmptyControllable is Controllable {
    constructor(address _controller) Controllable(_controller) {}
}

contract ControllableTest is EmintTest {
    Controller internal controller;
    EmptyControllable internal controllable;

    function setUp() public {
        controller = new Controller();
        controllable = new EmptyControllable(address(controller));
    }
}

contract TestControllable is ControllableTest {
    function test_set_dependency_reverts_if_not_overridden() public {
        vm.expectRevert(abi.encodeWithSelector(IControllable.InvalidDependency.selector, bytes32("value")));
        controller.setDependency(address(controllable), "value", address(0));
    }
}
