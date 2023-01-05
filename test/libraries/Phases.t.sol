// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../EmintTest.t.sol";
import {Raise, RaiseState, RaiseTokens, RaiseTimestamps, FeeSchedule} from "../../src/structs/Raise.sol";
import {ETH} from "../../src/constants/Constants.sol";
import "../../src/libraries/Phases.sol";

contract TestPhases is EmintTest {
    using Phases for Raise;

    function test_phase_is_scheduled_if_prior_to_presale() public {
        Raise memory raise = Raise({
            state: RaiseState.Active,
            projectId: 1,
            raiseId: 1,
            tokens: RaiseTokens(address(0), address(0)),
            feeSchedule: FeeSchedule({fanFee: 500, brandFee: 2500}),
            currency: ETH,
            goal: 10 ether,
            max: 1 ether,
            timestamps: RaiseTimestamps({
                presaleStart: uint64(block.timestamp) + 1 days,
                presaleEnd: uint64(block.timestamp) + 10 days,
                publicSaleStart: uint64(block.timestamp) + 10 days,
                publicSaleEnd: uint64(block.timestamp) + 20 days
            }),
            raised: 0,
            balance: 0,
            fees: 0
        });

        assertEq(uint8(raise.phase()), uint8(Phase.Scheduled));
    }

    function test_phase_is_ended_if_after_public_sale() public {
        Raise memory raise = Raise({
            state: RaiseState.Active,
            projectId: 1,
            raiseId: 1,
            tokens: RaiseTokens(address(0), address(0)),
            feeSchedule: FeeSchedule({fanFee: 500, brandFee: 2500}),
            currency: ETH,
            goal: 10 ether,
            max: 1 ether,
            timestamps: RaiseTimestamps({
                presaleStart: uint64(block.timestamp) + 1 days,
                presaleEnd: uint64(block.timestamp) + 10 days,
                publicSaleStart: uint64(block.timestamp) + 10 days,
                publicSaleEnd: uint64(block.timestamp) + 20 days
            }),
            raised: 0,
            balance: 0,
            fees: 0
        });

        vm.warp(raise.timestamps.publicSaleEnd + 1);
        assertEq(uint8(raise.phase()), uint8(Phase.Ended));
    }

    function test_phase_is_presale_if_during_presale_phase() public {
        Raise memory raise = Raise({
            state: RaiseState.Active,
            projectId: 1,
            raiseId: 1,
            tokens: RaiseTokens(address(0), address(0)),
            feeSchedule: FeeSchedule({fanFee: 500, brandFee: 2500}),
            currency: ETH,
            goal: 10 ether,
            max: 1 ether,
            timestamps: RaiseTimestamps({
                presaleStart: uint64(block.timestamp) + 1 days,
                presaleEnd: uint64(block.timestamp) + 10 days,
                publicSaleStart: uint64(block.timestamp) + 10 days,
                publicSaleEnd: uint64(block.timestamp) + 20 days
            }),
            raised: 0,
            balance: 0,
            fees: 0
        });

        vm.warp(raise.timestamps.presaleStart);
        assertEq(uint8(raise.phase()), uint8(Phase.Presale));
    }

    function test_phase_is_public_sale_if_during_public_sale_phase() public {
        Raise memory raise = Raise({
            state: RaiseState.Active,
            projectId: 1,
            raiseId: 1,
            tokens: RaiseTokens(address(0), address(0)),
            feeSchedule: FeeSchedule({fanFee: 500, brandFee: 2500}),
            currency: ETH,
            goal: 10 ether,
            max: 1 ether,
            timestamps: RaiseTimestamps({
                presaleStart: uint64(block.timestamp) + 1 days,
                presaleEnd: uint64(block.timestamp) + 10 days,
                publicSaleStart: uint64(block.timestamp) + 10 days,
                publicSaleEnd: uint64(block.timestamp) + 20 days
            }),
            raised: 0,
            balance: 0,
            fees: 0
        });

        vm.warp(raise.timestamps.publicSaleStart);
        assertEq(uint8(raise.phase()), uint8(Phase.PublicSale));
    }

    function test_phase_is_scheduled_between_disjoint_phases() public {
        Raise memory raise = Raise({
            state: RaiseState.Active,
            projectId: 1,
            raiseId: 1,
            tokens: RaiseTokens(address(0), address(0)),
            feeSchedule: FeeSchedule({fanFee: 500, brandFee: 2500}),
            currency: ETH,
            goal: 10 ether,
            max: 1 ether,
            timestamps: RaiseTimestamps({
                presaleStart: uint64(block.timestamp) + 1 days,
                presaleEnd: uint64(block.timestamp) + 10 days,
                publicSaleStart: uint64(block.timestamp) + 20 days,
                publicSaleEnd: uint64(block.timestamp) + 30 days
            }),
            raised: 0,
            balance: 0,
            fees: 0
        });

        vm.warp(raise.timestamps.presaleEnd + 1);
        assertEq(uint8(raise.phase()), uint8(Phase.Scheduled));
    }

    function test_all_phase_transitions() public {
        Raise memory raise = Raise({
            state: RaiseState.Active,
            projectId: 1,
            raiseId: 1,
            tokens: RaiseTokens(address(0), address(0)),
            feeSchedule: FeeSchedule({fanFee: 500, brandFee: 2500}),
            currency: ETH,
            goal: 10 ether,
            max: 1 ether,
            timestamps: RaiseTimestamps({
                presaleStart: uint64(block.timestamp) + 1 days,
                presaleEnd: uint64(block.timestamp) + 10 days,
                publicSaleStart: uint64(block.timestamp) + 20 days,
                publicSaleEnd: uint64(block.timestamp) + 30 days
            }),
            raised: 0,
            balance: 0,
            fees: 0
        });

        assertEq(uint8(raise.phase()), uint8(Phase.Scheduled));

        vm.warp(raise.timestamps.presaleStart);
        assertEq(uint8(raise.phase()), uint8(Phase.Presale));

        vm.warp(raise.timestamps.presaleEnd + 1);
        assertEq(uint8(raise.phase()), uint8(Phase.Scheduled));

        vm.warp(raise.timestamps.publicSaleStart);
        assertEq(uint8(raise.phase()), uint8(Phase.PublicSale));

        vm.warp(raise.timestamps.publicSaleEnd + 1);
        assertEq(uint8(raise.phase()), uint8(Phase.Ended));
    }
}
