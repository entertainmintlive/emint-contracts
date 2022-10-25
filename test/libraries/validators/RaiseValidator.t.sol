// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../EmintTest.t.sol";
import {RaiseParams} from "../../../src/structs/Raise.sol";
import {ETH} from "../../../src/constants/Constants.sol";
import "../../../src/libraries/validators/RaiseValidator.sol";
import "../../../src/TokenAuth.sol";
import {FakeERC20, IERC20} from "../../fakes/FakeERC20.sol";

contract TestRaiseValidations is EmintTest {
    using RaiseValidator for RaiseParams;

    address internal controller = mkaddr("controller");

    TokenAuth internal tokenAuth;
    IERC20 internal erc20;

    function setUp() public {
        tokenAuth = new TokenAuth(controller);
        erc20 = new FakeERC20();

        vm.prank(controller);
        tokenAuth.allow(address(erc20));
    }

    function test_validates_max_greater_than_goal() public {
        RaiseParams memory params = RaiseParams({
            currency: ETH,
            goal: 10 ether,
            max: 1 ether,
            presaleStart: uint64(block.timestamp),
            presaleEnd: uint64(block.timestamp) + 1 days,
            publicSaleStart: uint64(block.timestamp) + 1 days,
            publicSaleEnd: uint64(block.timestamp) + 10 days
        });

        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "max < goal"));
        params.validate(address(tokenAuth));
    }

    function test_does_not_revert_if_max_is_zero() public view {
        RaiseParams memory params = RaiseParams({
            currency: ETH,
            goal: 10 ether,
            max: 0,
            presaleStart: uint64(block.timestamp),
            presaleEnd: uint64(block.timestamp) + 1 days,
            publicSaleStart: uint64(block.timestamp) + 1 days,
            publicSaleEnd: uint64(block.timestamp) + 10 days
        });

        params.validate(address(tokenAuth));
    }

    function test_validates_presale_start_before_end() public {
        RaiseParams memory params = RaiseParams({
            currency: ETH,
            goal: 10 ether,
            max: 20 ether,
            presaleStart: uint64(block.timestamp) + 1 days,
            presaleEnd: uint64(block.timestamp),
            publicSaleStart: uint64(block.timestamp) + 1 days,
            publicSaleEnd: uint64(block.timestamp) + 10 days
        });

        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "end < start"));
        params.validate(address(tokenAuth));
    }

    function test_validates_public_sale_start_before_end() public {
        RaiseParams memory params = RaiseParams({
            currency: ETH,
            goal: 10 ether,
            max: 20 ether,
            presaleStart: uint64(block.timestamp),
            presaleEnd: uint64(block.timestamp) + 1 days,
            publicSaleStart: uint64(block.timestamp) + 1 days,
            publicSaleEnd: uint64(block.timestamp)
        });

        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "end <= start"));
        params.validate(address(tokenAuth));
    }

    function test_validates_presale_ends_before_public_sale() public {
        RaiseParams memory params = RaiseParams({
            currency: ETH,
            goal: 10 ether,
            max: 20 ether,
            presaleStart: uint64(block.timestamp),
            presaleEnd: uint64(block.timestamp) + 1 days,
            publicSaleStart: uint64(block.timestamp),
            publicSaleEnd: uint64(block.timestamp) + 10 days
        });

        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "public < presale"));
        params.validate(address(tokenAuth));
    }

    function test_validates_start_time_in_future() public {
        // The default timestamp in Forge is zero.
        // Warp forward so we can subtract a day.
        vm.warp(uint64(block.timestamp) + 1 days);

        RaiseParams memory params = RaiseParams({
            currency: ETH,
            goal: 10 ether,
            max: 20 ether,
            presaleStart: uint64(block.timestamp) - 1 days,
            presaleEnd: uint64(block.timestamp) + 1 days,
            publicSaleStart: uint64(block.timestamp) + 1 days,
            publicSaleEnd: uint64(block.timestamp) + 10 days
        });

        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "start <= now"));
        params.validate(address(tokenAuth));
    }

    function test_validates_max_length_of_presale() public {
        RaiseParams memory params = RaiseParams({
            currency: ETH,
            goal: 10 ether,
            max: 20 ether,
            presaleStart: uint64(block.timestamp),
            presaleEnd: uint64(block.timestamp) + 366 days,
            publicSaleStart: uint64(block.timestamp) + 366 days,
            publicSaleEnd: uint64(block.timestamp) + 376 days
        });

        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "too long"));
        params.validate(address(tokenAuth));
    }

    function test_validates_max_length_of_public_sale() public {
        RaiseParams memory params = RaiseParams({
            currency: ETH,
            goal: 10 ether,
            max: 20 ether,
            presaleStart: uint64(block.timestamp),
            presaleEnd: uint64(block.timestamp),
            publicSaleStart: uint64(block.timestamp),
            publicSaleEnd: uint64(block.timestamp) + 366 days
        });

        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "too long"));
        params.validate(address(tokenAuth));
    }

    function test_presale_can_start_and_end_at_same_time_as_public_sale() public view {
        RaiseParams memory params = RaiseParams({
            currency: ETH,
            goal: 10 ether,
            max: 20 ether,
            presaleStart: uint64(block.timestamp),
            presaleEnd: uint64(block.timestamp),
            publicSaleStart: uint64(block.timestamp),
            publicSaleEnd: uint64(block.timestamp) + 10 days
        });

        params.validate(address(tokenAuth));
    }
}
