// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC165Upgradeable} from "openzeppelin-contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {
    IERC1155Upgradeable,
    IERC1155MetadataURIUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {IERC2981Upgradeable} from "openzeppelin-contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

import "../EmintTest.t.sol";

import "../../src/tokens/Emint1155.sol";
import "../../src/Tokens.sol";
import "../../src/Metadata.sol";
import "../../src/Royalties.sol";
import "../../src/interfaces/ITokens.sol";
import "../../src/interfaces/ICommonErrors.sol";

import {TokenCodec} from "../../src/libraries/codecs/TokenCodec.sol";
import {RaiseCodec} from "../../src/libraries/codecs/RaiseCodec.sol";
import {TokenData, TokenType} from "../../src/structs/TokenData.sol";
import {RaiseData, TierType} from "../../src/structs/RaiseData.sol";

contract Emint1155Test is EmintTest, ERC1155Holder {
    Emint1155 internal token;

    Metadata internal metadata;
    Tokens internal tokens;
    Royalties internal royalties;

    address alice = mkaddr("alice");
    address bob = mkaddr("bob");
    address eve = mkaddr("eve");

    address controller = mkaddr("controller");
    address minter = mkaddr("minter");
    address protocol = mkaddr("protocol");
    address creators = mkaddr("creators");
    address owner = mkaddr("owner");
    address deployer = mkaddr("deployer");

    string constant DEFAULT_TOKEN_URI = "http://default-uri.com/";
    string constant DEFAULT_CONTRACT_URI = "http://default-uri.com/contract/";

    function setUp() public virtual {
        metadata = new Metadata(controller, DEFAULT_TOKEN_URI, DEFAULT_CONTRACT_URI, owner);

        vm.prank(controller);
        metadata.setDependency("creators", creators);

        royalties = new Royalties(controller, protocol);
        tokens = new Tokens(controller);

        vm.prank(controller);
        tokens.setDependency("deployer", deployer);

        vm.prank(deployer);
        token = Emint1155(tokens.deploy());

        vm.startPrank(controller);
        tokens.setDependency("minter", minter);
        tokens.setDependency("metadata", address(metadata));
        tokens.setDependency("royalties", address(royalties));
        vm.stopPrank();
    }
}

contract TestInitializer is Emint1155Test {
    function test_initializer_sets_tokens_address() public {
        assertEq(token.tokens(), address(tokens));
    }

    function test_initializer_cannot_be_called_twice() public {
        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize(address(0));
    }
}

contract TestMint is Emint1155Test {
    function setUp() public override {
        super.setUp();
    }

    function test_has_tokens_address() public {
        assertEq(token.tokens(), address(tokens));
    }

    function test_tokens_can_mint_one() public {
        vm.prank(address(tokens));
        token.mint(address(this), 1, 1, "");

        assertEq(token.balanceOf(address(this), 1), 1);
    }

    function test_non_tokens_cannot_mint_one() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        token.mint(address(this), 1, 1, "");
    }

    function test_tokens_can_mint_batch() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i; i < ids.length; ++i) {
            ids[i] = i + 1;
            amounts[i] = i + 1;
        }
        vm.prank(address(tokens));
        token.mintBatch(address(this), ids, amounts, "");

        assertEq(token.balanceOf(address(this), 1), 1);
        assertEq(token.balanceOf(address(this), 2), 2);
        assertEq(token.balanceOf(address(this), 3), 3);
    }

    function test_non_tokens_cannot_mint_batch() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        token.mintBatch(address(this), ids, amounts, "");
    }
}

contract TestMetadata is Emint1155Test {
    using Strings for address;

    function setUp() public override {
        super.setUp();
    }

    function test_has_metadata_address() public {
        assertEq(token.metadata(), address(metadata));
    }

    function test_delegates_uri_to_metadata() public {
        assertEq(token.uri(1), string.concat(DEFAULT_TOKEN_URI, "1.json"));

        vm.prank(creators);
        metadata.setCustomURI(1, "https://custom-uri.com/1.json");

        assertEq(token.uri(1), "https://custom-uri.com/1.json");
    }

    function test_delegates_contract_uri_to_metadata() public {
        assertEq(token.contractURI(), string.concat(DEFAULT_CONTRACT_URI, address(token).toHexString(), ".json"));
    }

    function test_delegates_owner_to_metadata() public {
        assertEq(token.owner(), owner);
    }
}

contract TestRoyalties is Emint1155Test {
    using TokenCodec for TokenData;
    using RaiseCodec for RaiseData;

    function setUp() public override {
        super.setUp();
    }

    function test_has_royalties_address() public {
        assertEq(token.royalties(), address(royalties));
    }

    function test_delegates_royalty_info_to_royalties_contract() public {
        RaiseData memory raiseData = RaiseData({tierType: TierType.Fan, projectId: 1, raiseId: 1, tierId: 1});
        TokenData memory tokenData =
            TokenData({tokenType: TokenType.Raise, encodingVersion: 0, data: raiseData.encode()});
        uint256 tokenId = tokenData.encode();
        (address receiver, uint256 royaltyAmount) = token.royaltyInfo(tokenId, 100 ether);
        assertEq(receiver, protocol);
        assertEq(royaltyAmount, 1.5 ether);
    }
}

contract TestInterfaceDetection is Emint1155Test {
    function setUp() public override {
        super.setUp();
    }

    function test_supports_erc165() public {
        assertEq(token.supportsInterface(type(IERC165Upgradeable).interfaceId), true);
    }

    function test_supports_erc1155() public {
        assertEq(token.supportsInterface(type(IERC1155Upgradeable).interfaceId), true);
    }

    function test_supports_erc1155_metadata() public {
        assertEq(token.supportsInterface(type(IERC1155MetadataURIUpgradeable).interfaceId), true);
    }

    function test_supports_erc2981() public {
        assertEq(token.supportsInterface(type(IERC2981Upgradeable).interfaceId), true);
    }
}

contract TestTransfers is Emint1155Test {
    function setUp() public override {
        super.setUp();
    }

    function test_transfer() public {
        vm.prank(address(tokens));
        token.mint(alice, 1, 1, "");

        assertEq(token.balanceOf(alice, 1), 1);
        assertEq(token.balanceOf(bob, 1), 0);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 1, 1, "");

        assertEq(token.balanceOf(alice, 1), 0);
        assertEq(token.balanceOf(bob, 1), 1);
    }

    function test_batch_transfer() public {
        vm.startPrank(address(tokens));
        token.mint(alice, 1, 1, "");
        token.mint(alice, 2, 1, "");
        vm.stopPrank();

        assertEq(token.balanceOf(alice, 1), 1);
        assertEq(token.balanceOf(alice, 2), 1);

        assertEq(token.balanceOf(bob, 1), 0);
        assertEq(token.balanceOf(bob, 2), 0);

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        ids[0] = 1;
        ids[1] = 2;

        amounts[0] = 1;
        amounts[1] = 1;

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(token.balanceOf(alice, 1), 0);
        assertEq(token.balanceOf(alice, 2), 0);

        assertEq(token.balanceOf(bob, 1), 1);
        assertEq(token.balanceOf(bob, 2), 1);
    }

    function test_batch_burn() public {
        vm.startPrank(address(tokens));
        token.mint(alice, 1, 1, "");
        token.mint(alice, 2, 1, "");
        vm.stopPrank();

        assertEq(token.balanceOf(alice, 1), 1);
        assertEq(token.balanceOf(alice, 2), 1);

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        ids[0] = 1;
        ids[1] = 2;

        amounts[0] = 1;
        amounts[1] = 1;

        vm.prank(alice);
        token.burnBatch(alice, ids, amounts);

        assertEq(token.balanceOf(alice, 1), 0);
        assertEq(token.balanceOf(alice, 2), 0);
    }
}

contract TestContractInfo is Emint1155Test {
    function setUp() public override {
        super.setUp();
    }

    function test_has_name() public {
        assertEq(token.NAME(), "Emint1155");
    }

    function test_has_version() public {
        assertEq(token.VERSION(), "0.0.1");
    }
}
