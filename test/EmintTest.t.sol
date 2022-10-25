// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

contract EmintTest is Test {
    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }
}
