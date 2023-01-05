// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Pausable} from "openzeppelin-contracts/security/Pausable.sol";

import {Controllable} from "../../src/abstract/Controllable.sol";

contract FakePausable is Pausable, Controllable {
    constructor(address _controller) Controllable(_controller) {}

    function pause() external onlyController {
        _pause();
    }

    function unpause() external onlyController {
        _unpause();
    }
}
