// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./EmintTest.t.sol";
import "../src/Royalties.sol";
import "../src/interfaces/ICommonErrors.sol";
import "../src/libraries/codecs/TokenCodec.sol";
import "../src/libraries/codecs/RaiseCodec.sol";

contract RoyaltiesTest is EmintTest {
    Royalties internal royalties;

    address controller = mkaddr("controller");
    address protocol = mkaddr("protocol");

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

contract TestContractInfo is RoyaltiesTest {
    function test_has_name() public {
        assertEq(royalties.NAME(), "Royalties");
    }

    function test_has_version() public {
        assertEq(royalties.VERSION(), "0.0.1");
    }
}
