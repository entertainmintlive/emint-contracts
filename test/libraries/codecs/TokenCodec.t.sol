// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../EmintTest.t.sol";
import "../../../src/libraries/codecs/TokenCodec.sol";

contract TestTokenEncodings is EmintTest {
    function test_token_type_mask() public {
        assertEq(TOKEN_TYPE_MASK, 0x00000000000000000000000000000000000000000000000000000000000000ff);
    }

    function test_encoding_version_mask() public {
        assertEq(ENCODING_VERSION_MASK, 0x000000000000000000000000000000000000000000000000000000000000ff00);
    }

    function test_data_region_mask() public {
        assertEq(DATA_REGION_MASK, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000);
    }

    function test_encodes_token_to_token_id() public {
        TokenData memory token =
            TokenData({data: bytes30(type(uint240).max), encodingVersion: 2, tokenType: TokenType.Raise});
        uint256 tokenId = TokenCodec.encode(token);
        assertEq(tokenId, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0200);
    }

    function test_decodes_token_id_to_token() public {
        TokenData memory token =
            TokenData({tokenType: TokenType.Raise, encodingVersion: 2, data: bytes30(type(uint240).max)});
        uint256 tokenId = TokenCodec.encode(token);
        TokenData memory decoded = TokenCodec.decode(tokenId);
        assertEq(uint8(decoded.tokenType), uint8(TokenType.Raise));
        assertEq(decoded.encodingVersion, 2);
        assertEq(decoded.data, bytes30(type(uint240).max));
    }
}

contract FuzzTokenEncodings is EmintTest {
    function test_encode_decode(uint8 encodingVersion, bytes30 data) public {
        TokenData memory token = TokenData({tokenType: TokenType.Raise, encodingVersion: encodingVersion, data: data});
        uint256 tokenId = TokenCodec.encode(token);
        TokenData memory decoded = TokenCodec.decode(tokenId);
        assertEq(uint8(decoded.tokenType), uint8(TokenType.Raise));
        assertEq(decoded.encodingVersion, encodingVersion);
        assertEq(decoded.data, data);
    }
}
