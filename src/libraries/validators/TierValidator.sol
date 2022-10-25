// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TierParams} from "../../structs/Tier.sol";

error ValidationError(string message);

/// @title TierValidator - Tier parameter validator
library TierValidator {
    function validate(TierParams memory tier) internal pure {
        if (tier.supply == 0) {
            revert ValidationError("zero supply");
        }
    }
}
