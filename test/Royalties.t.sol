// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./EmintTest.t.sol";
import "../src/Royalties.sol";
import "../src/interfaces/ICommonErrors.sol";
import "../src/libraries/codecs/TokenCodec.sol";
import "../src/libraries/codecs/RaiseCodec.sol";

contract RoyaltiesTest is EmintTest {
    Royalties internal royalties;

    address controller = mkaddr("controller");
    address protocol = mkaddr("protocol");
    address alice = mkaddr("alice");

    function setUp() public {
        royalties = new Royalties(controller, protocol);
    }
}

contract TestRoyalties is RoyaltiesTest {
    using TokenCodec for TokenData;
    using RaiseCodec for RaiseData;

    function test_calculates_royalties_for_fan_token() public {
        RaiseData memory raiseData = RaiseData({tierType: TierType.Fan, projectId: 1, raiseId: 1, tierId: 1});
        TokenData memory tokenData =
            TokenData({tokenType: TokenType.Raise, encodingVersion: 0, data: raiseData.encode()});
        uint256 tokenId = tokenData.encode();
        (address receiver, uint256 royaltyAmount) = royalties.royaltyInfo(tokenId, 100 ether);
        assertEq(receiver, protocol);
        assertEq(royaltyAmount, 1.5 ether);
    }

    function test_calculates_royalties_for_brand_token() public {
        RaiseData memory raiseData = RaiseData({tierType: TierType.Brand, projectId: 1, raiseId: 1, tierId: 1});
        TokenData memory tokenData =
            TokenData({tokenType: TokenType.Raise, encodingVersion: 0, data: raiseData.encode()});
        uint256 tokenId = tokenData.encode();
        (address receiver, uint256 royaltyAmount) = royalties.royaltyInfo(tokenId, 100 ether);
        assertEq(receiver, protocol);
        assertEq(royaltyAmount, 10 ether);
    }
}

contract TestController is RoyaltiesTest {
    event SetReceiver(address oldReceiver, address newReceiver);

    function test_has_controller_address() public {
        assertEq(royalties.controller(), controller);
    }

    function test_controller_address_zero_check() public {
        vm.expectRevert(ICommonErrors.ZeroAddress.selector);
        new Royalties(address(0), protocol);
    }

    function test_controller_can_set_new_receiver() public {
        address newReceiver = mkaddr("new reciever");

        vm.prank(controller);
        royalties.setDependency("receiver", newReceiver);

        assertEq(royalties.receiver(), newReceiver);
    }

    function test_set_receiver_emits_event() public {
        address newReceiver = mkaddr("new reciever");

        vm.expectEmit(false, false, false, true);
        emit SetReceiver(protocol, newReceiver);

        vm.prank(controller);
        royalties.setDependency("receiver", newReceiver);
    }

    function test_non_controller_cannot_set_new_receiver() public {
        address newReceiver = mkaddr("new reciever");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        royalties.setDependency("receiver", newReceiver);
    }

    function test_controller_cannot_set_invalid_dependency() public {
        address invalid = mkaddr("invalid");

        vm.expectRevert(abi.encodeWithSelector(IControllable.InvalidDependency.selector, bytes32("invalid")));
        vm.prank(controller);
        royalties.setDependency("invalid", invalid);
    }

    function test_controller_cannot_set_zero_address() public {
        vm.expectRevert(ICommonErrors.ZeroAddress.selector);
        vm.prank(controller);
        royalties.setDependency("receiver", address(0));
    }
}

contract TestReceiver is RoyaltiesTest {
    function test_has_receiver_address() public {
        assertEq(royalties.receiver(), protocol);
    }

    function test_receiver_address_zero_check() public {
        vm.expectRevert(ICommonErrors.ZeroAddress.selector);
        new Royalties(controller, address(0));
    }
}

contract TestRoyaltySchedule is RoyaltiesTest {
    using TokenCodec for TokenData;
    using RaiseCodec for RaiseData;

    event SetRoyaltySchedule(RoyaltySchedule oldRoyaltySchedule, RoyaltySchedule newRoyaltySchedule);

    function test_controller_can_set_royalty_schedule() public {
        (uint16 fanRoyalty, uint16 brandRoyalty) = royalties.royaltySchedule();
        assertEq(fanRoyalty, 150);
        assertEq(brandRoyalty, 1000);

        RoyaltySchedule memory oldRoyaltySchedule = RoyaltySchedule({fanRoyalty: 150, brandRoyalty: 1000});

        RoyaltySchedule memory newRoyaltySchedule = RoyaltySchedule({fanRoyalty: 500, brandRoyalty: 2500});

        vm.expectEmit(false, false, false, true);
        emit SetRoyaltySchedule(oldRoyaltySchedule, newRoyaltySchedule);

        vm.prank(controller);
        royalties.setRoyaltySchedule(newRoyaltySchedule);

        (fanRoyalty, brandRoyalty) = royalties.royaltySchedule();
        assertEq(fanRoyalty, 500);
        assertEq(brandRoyalty, 2500);
    }

    function test_non_controller_cannot_set_royalty_schedule() public {
        RoyaltySchedule memory newRoyaltySchedule = RoyaltySchedule({fanRoyalty: 500, brandRoyalty: 2500});

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        vm.prank(alice);
        royalties.setRoyaltySchedule(newRoyaltySchedule);
    }

    function test_royalty_info_uses_stored_royalty_schedule() public {
        RoyaltySchedule memory newRoyaltySchedule = RoyaltySchedule({fanRoyalty: 500, brandRoyalty: 2500});

        vm.prank(controller);
        royalties.setRoyaltySchedule(newRoyaltySchedule);

        RaiseData memory brandRaiseData = RaiseData({tierType: TierType.Brand, projectId: 1, raiseId: 1, tierId: 1});
        TokenData memory brandTokenData =
            TokenData({tokenType: TokenType.Raise, encodingVersion: 0, data: brandRaiseData.encode()});
        uint256 brandTokenId = brandTokenData.encode();

        (address receiver, uint256 royaltyAmount) = royalties.royaltyInfo(brandTokenId, 100 ether);
        assertEq(receiver, protocol);
        assertEq(royaltyAmount, 25 ether);

        RaiseData memory fanRaiseData = RaiseData({tierType: TierType.Fan, projectId: 1, raiseId: 1, tierId: 1});
        TokenData memory fanTokenData =
            TokenData({tokenType: TokenType.Raise, encodingVersion: 0, data: fanRaiseData.encode()});
        uint256 fanTokenId = fanTokenData.encode();

        (receiver, royaltyAmount) = royalties.royaltyInfo(fanTokenId, 100 ether);
        assertEq(receiver, protocol);
        assertEq(royaltyAmount, 5 ether);
    }

    function test_reverts_if_fan_royalty_invalid() public {
        RoyaltySchedule memory newRoyaltySchedule = RoyaltySchedule({fanRoyalty: 10_000, brandRoyalty: 2500});

        vm.expectRevert(IRoyalties.InvalidRoyalty.selector);
        vm.prank(controller);
        royalties.setRoyaltySchedule(newRoyaltySchedule);
    }

    function test_reverts_if_brand_royalty_invalid() public {
        RoyaltySchedule memory newRoyaltySchedule = RoyaltySchedule({fanRoyalty: 500, brandRoyalty: 10_000});

        vm.expectRevert(IRoyalties.InvalidRoyalty.selector);
        vm.prank(controller);
        royalties.setRoyaltySchedule(newRoyaltySchedule);
    }
}

contract TestCustomRoyalties is RoyaltiesTest {
    event SetCustomRoyalty(uint256 indexed tokenId, CustomRoyalty customRoyalty);

    function test_controller_can_set_custom_royalty() public {
        (address receiver, uint16 royaltyBps) = royalties.customRoyalties(1);
        assertEq(receiver, address(0));
        assertEq(royaltyBps, 0);

        CustomRoyalty memory customRoyalty = CustomRoyalty({receiver: alice, royaltyBps: 500});

        vm.expectEmit(true, false, false, true);
        emit SetCustomRoyalty(1, customRoyalty);

        vm.prank(controller);
        royalties.setCustomRoyalty(1, customRoyalty);

        (receiver, royaltyBps) = royalties.customRoyalties(1);
        assertEq(receiver, alice);
        assertEq(royaltyBps, 500);
    }

    function test_non_controller_cannot_set_custom_royalty() public {
        CustomRoyalty memory customRoyalty = CustomRoyalty({receiver: alice, royaltyBps: 500});

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        vm.prank(alice);
        royalties.setCustomRoyalty(1, customRoyalty);
    }

    function test_royalty_info_uses_custom_royalty_when_present() public {
        CustomRoyalty memory customRoyalty = CustomRoyalty({receiver: alice, royaltyBps: 500});

        vm.prank(controller);
        royalties.setCustomRoyalty(1, customRoyalty);

        (address receiver, uint256 royaltyAmount) = royalties.royaltyInfo(1, 100 ether);
        assertEq(receiver, alice);
        assertEq(royaltyAmount, 5 ether);
    }

    function test_reverts_if_receiver_is_zero_address() public {
        CustomRoyalty memory customRoyalty = CustomRoyalty({receiver: address(0), royaltyBps: 500});

        vm.expectRevert(IRoyalties.InvalidReceiver.selector);
        vm.prank(controller);
        royalties.setCustomRoyalty(1, customRoyalty);
    }

    function test_reverts_if_royalty_invalid() public {
        CustomRoyalty memory customRoyalty = CustomRoyalty({receiver: alice, royaltyBps: 10_000});

        vm.expectRevert(IRoyalties.InvalidRoyalty.selector);
        vm.prank(controller);
        royalties.setCustomRoyalty(1, customRoyalty);
    }
}

contract TestContractInfo is RoyaltiesTest {
    function test_has_name() public {
        assertEq(royalties.NAME(), "Royalties");
    }

    function test_has_version() public {
        assertEq(royalties.VERSION(), "0.0.1");
    }
}
