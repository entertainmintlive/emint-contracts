// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TierType} from "../structs/Tier.sol";

uint256 constant BPS_DENOMINATOR = 10_000;

/// @title Fees - Fee calculator
/// @notice Calculates protocol fee based on token mint price.
library Fees {
    function calculate(TierType tierType, uint256 mintPrice)
        internal
        pure
        returns (uint256 protocolFee, uint256 creatorTake)
    {
        uint256 feeBps = (tierType == TierType.Fan) ? 500 : 2500;
        protocolFee = (feeBps * mintPrice) / BPS_DENOMINATOR;
        creatorTake = mintPrice - protocolFee;
    }
}
