// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {EmintV1ForkTest} from "./EmintV1ForkTest.t.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {IERC1155} from "forge-std/interfaces/IERC1155.sol";

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

interface IOperatorFilterRegistry {
    function filteredOperators(address addr) external returns (address[] memory);
}

contract ValidationTest is EmintV1ForkTest(0) {
    address constant CANONICAL_OPERATOR_FILTER_REGISTRY = 0x000000000000AAeB6D7670E522A718067333cd4E;
    address constant CANONICAL_OPENSEA_REGISTRANT = 0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6;

    address[] filteredOperators;

    uint256 fanTokenId;
    uint256 brandTokenId;

    function setUp() public virtual override {
        super.setUp();

        filteredOperators =
            IOperatorFilterRegistry(CANONICAL_OPERATOR_FILTER_REGISTRY).filteredOperators(CANONICAL_OPENSEA_REGISTRANT);

        vm.prank(owner);
        controller.acceptOwnership();

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
        TierParams[] memory tierParams = new TierParams[](2);
        tierParams[0] =
            TierParams({tierType: TierType.Fan, supply: 10, price: 0.01 ether, limitPerAddress: 3, allowListRoot: ""});
        tierParams[1] =
            TierParams({tierType: TierType.Brand, supply: 10, price: 0.1 ether, limitPerAddress: 3, allowListRoot: ""});

        uint32 raiseId = creators.createRaise(projectId, raiseParams, tierParams);
        vm.stopPrank();

        // Warp to sale phase
        vm.warp(raiseParams.publicSaleStart);

        // Bob mints a fan token
        vm.prank(bob);
        fanTokenId = raises.mint{value: 0.01 ether}(projectId, raiseId, 0, 1);
        assertEq(tokens.token(fanTokenId).balanceOf(bob, fanTokenId), 1);

        // Pepsi mints a brand token
        vm.prank(pepsi);
        brandTokenId = raises.mint{value: 0.1 ether}(projectId, raiseId, 1, 1);
        assertEq(tokens.token(brandTokenId).balanceOf(pepsi, brandTokenId), 1);
    }

    function test_fan_token() public {
        address contractAddress = address(tokens.token(fanTokenId));
        _test_opensea_operator_filter(contractAddress, bob, fanTokenId);
    }

    function test_deployed_fan_token() public {
        address contractAddress = address(0x0238A6A9496508DfFb3110Bd115E669b86Dd7059);
        address tokenOwner = address(0x8F3EC94C76EefBc23601e2D29fbf84f6639BAe01);
        uint256 tokenId = 1208925819896104151482368;
        _test_opensea_operator_filter(contractAddress, tokenOwner, tokenId);
    }

    function test_brand_token() public {
        address contractAddress = address(tokens.token(brandTokenId));
        _test_opensea_operator_filter(contractAddress, pepsi, brandTokenId);
    }

    function test_deployed_brand_token() public {
        address contractAddress = address(0xde0D89b618e31DFfe2F0B76E3FC6bF393D418769);
        address tokenOwner = address(0x57b49C6CB01Cfd30588B2F7BFb3621Dd2A0af468);
        uint256 tokenId = 5192296858534827628811971305996288;
        _test_opensea_operator_filter(contractAddress, tokenOwner, tokenId);
    }


    function _test_opensea_operator_filter(address contractAddress, address _owner, uint256 tokenId) internal {
        IERC1155 nftContract = IERC1155(contractAddress);
        for (uint256 i = 0; i < filteredOperators.length; i++) {
            address operator = filteredOperators[i];

            // Try to set approval for the operator
            vm.prank(_owner);
            try nftContract.setApprovalForAll(operator, true) {}
            catch (bytes memory) {
                // even if approval reverts, continue to test transfer methods, since marketplace approvals can be
                // hard-coded into contracts
            }

            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = tokenId;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = 1;

            // Ensure operator is not able to transfer the token
            vm.startPrank(operator);
            vm.expectRevert();
            nftContract.safeTransferFrom(_owner, address(1), tokenId, 1, "");

            vm.expectRevert();
            nftContract.safeBatchTransferFrom(_owner, address(1), tokenIds, amounts, "");

            vm.stopPrank();
        }
    }

    function test_opensea_operator_filter_brand_token() public {
        address contractAddress = address(tokens.token(brandTokenId));
        owner = pepsi;
        uint256 tokenId = brandTokenId;

        IERC1155 nftContract = IERC1155(contractAddress);
        for (uint256 i = 0; i < filteredOperators.length; i++) {
            address operator = filteredOperators[i];

            // Try to set approval for the operator
            vm.prank(owner);
            try nftContract.setApprovalForAll(operator, true) {}
            catch (bytes memory) {
                // even if approval reverts, continue to test transfer methods, since marketplace approvals can be
                // hard-coded into contracts
            }

            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = tokenId;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = 1;

            // Ensure operator is not able to transfer the token
            vm.startPrank(operator);
            vm.expectRevert();
            nftContract.safeTransferFrom(owner, address(1), tokenId, 1, "");

            vm.expectRevert();
            nftContract.safeBatchTransferFrom(owner, address(1), tokenIds, amounts, "");

            vm.stopPrank();
        }
    }
}
