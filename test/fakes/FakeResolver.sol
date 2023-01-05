// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../src/interfaces/IMetadataResolver.sol";

contract FakeResolver is IMetadataResolver {
    string internal _uri;

    constructor(string memory uri_) {
        _uri = uri_;
    }

    function uri(uint256) external view returns (string memory) {
        return _uri;
    }
}
