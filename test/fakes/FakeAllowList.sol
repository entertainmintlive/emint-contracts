// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {AllowList} from "../../src/abstract/AllowList.sol";

contract FakeAllowList is AllowList {
    constructor(address _controller) AllowList(_controller) {}
}
