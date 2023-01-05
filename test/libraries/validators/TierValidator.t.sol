// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../EmintTest.t.sol";
import {TierParams, TierType} from "../../../src/structs/Tier.sol";
import "../../../src/libraries/validators/TierValidator.sol";

contract TestRaiseValidations is EmintTest {
    using TierValidator for TierParams;

    function test_validates_nonzero_supply() public {
        TierParams memory params = TierParams({
            tierType: TierType.Fan,
            supply: 0,
            price: 1 ether,
            limitPerAddress: 10,
            allowListRoot: bytes32("")
        });

        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "zero supply"));
        params.validate();
    }

    function test_validates_nonzero_limit() public {
        TierParams memory params = TierParams({
            tierType: TierType.Fan,
            supply: 10,
            price: 1 ether,
            limitPerAddress: 0,
            allowListRoot: bytes32("")
        });

        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "zero limit"));
        params.validate();
    }

    function test_allows_zero_price() public pure {
        TierParams memory params =
            TierParams({tierType: TierType.Fan, supply: 10, price: 0, limitPerAddress: 1, allowListRoot: bytes32("")});

        params.validate();
    }
}
