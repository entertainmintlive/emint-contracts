// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {EmintV1ForkTest} from "./EmintV1ForkTest.t.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

import "../../src/Controller.sol";
import "../../src/TokenAuth.sol";
import "../../src/CreatorAuth.sol";
import "../../src/Projects.sol";
import "../../src/Creators.sol";
import "../../src/Raises.sol";
import "../../src/Metadata.sol";
import "../../src/Royalties.sol";
import "../../src/Minter.sol";
import "../../src/Tokens.sol";

contract TestDeployment is EmintV1ForkTest(15_500_000) {
    function test_owner_can_accept_ownership() public {
        assertEq(controller.owner(), contracts.fab);

        vm.prank(owner);
        controller.acceptOwnership();

        assertEq(controller.owner(), owner);
    }
}

contract TestRaiseEndToEnd is EmintV1ForkTest(15_500_000) {
    using Strings for address;

    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        controller.acceptOwnership();
    }

    function test_successful_raise_end_to_end() public {
        // Owner adds alice to creator allowlist
        vm.prank(owner);
        controller.allow(contracts.creatorAuth, alice);

        // Alice creates a project and raise
        vm.startPrank(alice);
        uint32 projectId = creators.createProject();

        RaiseParams memory raiseParams = RaiseParams({
            currency: ETH,
            goal: 10 ether,
            max: 25 ether,
            presaleStart: uint64(block.timestamp) + 1 days,
            presaleEnd: uint64(block.timestamp) + 10 days,
            publicSaleStart: uint64(block.timestamp) + 10 days,
            publicSaleEnd: uint64(block.timestamp) + 20 days
        });
        TierParams[] memory tierParams = new TierParams[](5);
        tierParams[0] =
            TierParams({tierType: TierType.Fan, supply: 100, price: 0.02 ether, limitPerAddress: 5, allowListRoot: ""});
        tierParams[1] =
            TierParams({tierType: TierType.Fan, supply: 30, price: 0.1 ether, limitPerAddress: 3, allowListRoot: ""});
        tierParams[2] =
            TierParams({tierType: TierType.Fan, supply: 10, price: 0.5 ether, limitPerAddress: 1, allowListRoot: ""});
        tierParams[3] =
            TierParams({tierType: TierType.Brand, supply: 1, price: 5 ether, limitPerAddress: 1, allowListRoot: ""});
        tierParams[4] =
            TierParams({tierType: TierType.Brand, supply: 1, price: 10 ether, limitPerAddress: 1, allowListRoot: ""});

        uint32 raiseId = creators.createRaise(projectId, raiseParams, tierParams);

        // Alice updates raise goal amount and start time.
        raiseParams.goal = 15 ether;
        raiseParams.presaleStart = uint64(block.timestamp) + 2 days;
        creators.updateRaise(projectId, raiseId, raiseParams, tierParams);
        vm.stopPrank();

        // TODO: presale phase with real allowlists

        // Warp to sale phase
        vm.warp(raiseParams.publicSaleStart);

        // Bob mints 3 Tier 0 fan tokens
        vm.prank(bob);
        uint256 tokenId = raises.mint{value: 0.06 ether}(projectId, raiseId, 0, 3);
        assertEq(tokens.token(tokenId).balanceOf(bob, tokenId), 3);

        // Carol mints 3 total Tier 1 fan tokens
        vm.startPrank(carol);
        tokenId = raises.mint{value: 0.2 ether}(projectId, raiseId, 1, 2);
        assertEq(tokens.token(tokenId).balanceOf(carol, tokenId), 2);
        raises.mint{value: 0.1 ether}(projectId, raiseId, 1, 1);
        assertEq(tokens.token(tokenId).balanceOf(carol, tokenId), 3);
        vm.stopPrank();

        // Dave mints 1 Tier 2 fan token, 3 Tier 1 tokens, and 5 tier 0 fan tokens
        vm.startPrank(dave);
        tokenId = raises.mint{value: 0.5 ether}(projectId, raiseId, 2, 1);
        assertEq(tokens.token(tokenId).balanceOf(dave, tokenId), 1);
        tokenId = raises.mint{value: 0.3 ether}(projectId, raiseId, 1, 3);
        assertEq(tokens.token(tokenId).balanceOf(dave, tokenId), 3);
        tokenId = raises.mint{value: 0.1 ether}(projectId, raiseId, 0, 5);
        assertEq(tokens.token(tokenId).balanceOf(dave, tokenId), 5);
        vm.stopPrank();

        // Pepsi mints 1 Tier 3 brand token
        vm.prank(pepsi);
        tokenId = raises.mint{value: 5 ether}(projectId, raiseId, 3, 1);
        assertEq(tokens.token(tokenId).balanceOf(pepsi, tokenId), 1);

        // Disney cannot mint the Tier 3 brand token
        vm.prank(disney);
        vm.expectRevert(IRaises.RaiseSoldOut.selector);
        raises.mint{value: 5 ether}(projectId, raiseId, 3, 1);

        // ...but they can mint the Tier 4 brand token
        vm.prank(disney);
        raises.mint{value: 10 ether}(projectId, raiseId, 4, 1);

        // Check in on raise accounting
        Raise memory raise = raises.getRaise(projectId, raiseId);
        assertEq(raise.raised, 16.26 ether); // Total raised
        assertEq(raise.balance, 12.447 ether); // Creator balance
        assertEq(raise.fees, 3.813 ether); // Protocol fees

        // Alice closes the raise
        vm.prank(alice);
        creators.closeRaise(projectId, raiseId);

        // Alice withdraws her funds to her own address
        vm.prank(alice);
        creators.withdrawRaiseFunds(projectId, raiseId, alice);
        assertEq(address(alice).balance, 12.447 ether);

        IEmint1155 token = tokens.token(tokenId);

        // Tokens have default metadata
        assertEq(
            token.uri(tokenId),
            "https://staging-entertainmint.com/api/metadata/tokens/5192296862161605087655858830114816.json"
        );

        // Tokens have contract metadata
        assertEq(
            token.contractURI(),
            string.concat(
                "https://staging-entertainmint.com/api/metadata/contracts/",
                address(tokens.token(tokenId)).toHexString(),
                ".json"
            )
        );

        // Tokens cannot be burned by non-owner
        vm.expectRevert("ERC1155: caller is not token owner or approved");
        token.burn(pepsi, tokenId, 1);

        // Tokens are transferrable
        vm.prank(pepsi);
        token.safeTransferFrom(pepsi, disney, tokenId, 1, "");

        // Tokens can be burned by owner
        vm.prank(disney);
        token.burn(disney, tokenId, 1);
        assertEq(token.balanceOf(disney, tokenId), 0);

        // Alice can create a new raise for the same project
        raiseParams.presaleStart = uint64(block.timestamp) + 1 days;
        raiseParams.presaleEnd = uint64(block.timestamp) + 10 days;
        raiseParams.publicSaleStart = uint64(block.timestamp) + 10 days;
        raiseParams.publicSaleEnd = uint64(block.timestamp) + 20 days;

        vm.prank(alice);
        uint32 nextRaise = creators.createRaise(projectId, raiseParams, tierParams);
        assertEq(nextRaise, raiseId + 1);

        // Alice can create a new project
        vm.prank(alice);
        uint32 nextProject = creators.createProject();
        assertEq(nextProject, projectId + 1);
    }
}
