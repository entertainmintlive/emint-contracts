// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../EmintTest.t.sol";
import "../../../src/libraries/codecs/RaiseCodec.sol";

contract TestRaiseEncodings is EmintTest {
    function test_project_id_mask() public {
        assertEq(PROJECT_ID_MASK, 0x0000000000000000000000000000000000000000000000000000ffffffff);
    }

    function test_raise_id_mask() public {
        assertEq(RAISE_ID_MASK, 0x00000000000000000000000000000000000000000000ffffffff00000000);
    }

    function test_tier_id_mask() public {
        assertEq(TIER_ID_MASK, 0x000000000000000000000000000000000000ffffffff0000000000000000);
    }

    function test_tier_type_id_mask() public {
        assertEq(TIER_TYPE_MASK, 0x0000000000000000000000000000000000ff000000000000000000000000);
    }

    function test_encodes_raise_to_bytes30() public {
        RaiseData memory raise = RaiseData({tierType: TierType.Brand, tierId: 1, raiseId: 2, projectId: 3});
        bytes30 raiseData = RaiseCodec.encode(raise);
        assertEq(uint240(raiseData), 0x000000000000000000000000000000000001000000010000000200000003);
    }

    function test_decodes_token_id_to_token() public {
        RaiseData memory raise = RaiseData({tierType: TierType.Brand, tierId: 1, raiseId: 2, projectId: 3});
        bytes30 raiseData = RaiseCodec.encode(raise);
        RaiseData memory decoded = RaiseCodec.decode(raiseData);
        assertEq(uint8(decoded.tierType), uint8(TierType.Brand));
        assertEq(decoded.tierId, 1);
        assertEq(decoded.raiseId, 2);
        assertEq(decoded.projectId, 3);
    }
}

contract FuzzRaiseEncodings is EmintTest {
    function test_encode_decode(uint8 tierType, uint32 tierId, uint32 raiseId, uint32 projectId) public {
        vm.assume(tierType < 2);
        RaiseData memory raise =
            RaiseData({tierType: TierType(tierType), tierId: tierId, raiseId: raiseId, projectId: projectId});
        bytes30 raiseData = RaiseCodec.encode(raise);
        RaiseData memory decoded = RaiseCodec.decode(raiseData);
        assertEq(uint8(decoded.tierType), uint8(tierType));
        assertEq(decoded.tierId, tierId);
        assertEq(decoded.raiseId, raiseId);
        assertEq(decoded.projectId, projectId);
    }
}
