// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AllowList} from "../../src/abstract/AllowList.sol";

contract FakeAllowList is AllowList {
    constructor(address _controller) AllowList(_controller) {}
}
