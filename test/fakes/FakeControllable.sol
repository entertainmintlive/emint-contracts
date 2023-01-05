// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Controllable} from "../../src/abstract/Controllable.sol";
import {IControllable} from "../../src/interfaces/IControllable.sol";

contract FakeControllable is Controllable {
    address public dependency;

    constructor(address _controller, address _dependency) Controllable(_controller) {
        dependency = _dependency;
    }

    function setDependency(bytes32 _name, address _contract) external override onlyController {
        if (_name == "dependency") dependency = _contract;
        else revert InvalidDependency(_name);
    }
}
