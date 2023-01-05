// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

import "./EmintTest.t.sol";
import "./fakes/FakeResolver.sol";
import "../src/interfaces/IMetadata.sol";
import "../src/interfaces/ICommonErrors.sol";
import "../src/Metadata.sol";

contract MetadataTest is EmintTest {
    Metadata internal metadata;
    IMetadataResolver internal customResolver;

    address controller = mkaddr("controller");
    address creators = mkaddr("creators");
    address owner = mkaddr("owner");

    event SetCustomURI(uint256 indexed tokenId, string customURI);
    event SetCustomResolver(uint256 indexed tokenId, IMetadataResolver customResolver);
    event SetCollectionOwner(address collection, address owner);
    event SetCreators(address oldCreators, address newCreators);
    event SetTokenURIBase(string oldURI, string newURI);
    event SetContractURIBase(string oldURI, string newURI);
    event SetDefaultCollectionOwner(address oldOwner, address newOwner);

    string constant DEFAULT_CONTRACT_URI = "http://default-uri.com/contracts/";
    string constant DEFAULT_TOKEN_URI = "http://default-uri.com/tokens/";
    string constant CUSTOM_TOKEN_URI = "http://custom-uri.com/1234.json";
    string constant CUSTOM_RESOLVER_TOKEN_URI = "http://custom-resolver-uri.com/1234.json";

    function setUp() public {
        metadata = new Metadata(controller, DEFAULT_TOKEN_URI, DEFAULT_CONTRACT_URI, owner);
        customResolver = new FakeResolver(CUSTOM_RESOLVER_TOKEN_URI);
        vm.prank(controller);
        metadata.setDependency("creators", creators);
    }
}

contract TestController is MetadataTest {
    function test_has_controller_address() public {
        assertEq(metadata.controller(), controller);
    }

    function test_controller_address_zero_check() public {
        vm.expectRevert(ICommonErrors.ZeroAddress.selector);
        new Metadata(address(0), DEFAULT_TOKEN_URI, DEFAULT_CONTRACT_URI, owner);
    }

    function test_controller_can_set_creators() public {
        address newCreators = mkaddr("new creators");

        vm.prank(controller);
        metadata.setDependency("creators", newCreators);

        assertEq(metadata.creators(), newCreators);
    }

    function test_non_controller_cannot_set_creators() public {
        address newCreators = mkaddr("new creators");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        metadata.setDependency("creators", newCreators);
    }

    function test_set_creators_emits_event() public {
        address newCreators = mkaddr("new creators");

        vm.expectEmit(false, false, false, true);
        emit SetCreators(creators, newCreators);

        vm.prank(controller);
        metadata.setDependency("creators", newCreators);
    }

    function test_controller_can_set_default_uri() public {
        string memory newTokenURIBase = "https://new-default-uri.com/";

        vm.prank(controller);
        metadata.setTokenURIBase(newTokenURIBase);

        assertEq(metadata.tokenURIBase(), newTokenURIBase);
    }

    function test_non_controller_cannot_set_default_uri() public {
        string memory newTokenURIBase = "https://new-default-uri.com/";

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        metadata.setTokenURIBase(newTokenURIBase);
    }

    function test_set_default_uri_emits_event() public {
        string memory newTokenURIBase = "https://new-default-uri.com/";

        vm.expectEmit(false, false, false, true);
        emit SetTokenURIBase(DEFAULT_TOKEN_URI, newTokenURIBase);

        vm.prank(controller);
        metadata.setTokenURIBase(newTokenURIBase);
    }

    function test_controller_can_set_contract_uri() public {
        string memory newContractURIBase = "https://new-contract-uri.com/";

        vm.prank(controller);
        metadata.setContractURIBase(newContractURIBase);

        assertEq(metadata.contractURIBase(), newContractURIBase);
    }

    function test_non_controller_cannot_set_contract_uri() public {
        string memory newContractURIBase = "https://new-contract-uri.com/";

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        metadata.setContractURIBase(newContractURIBase);
    }

    function test_set_contract_uri_emits_event() public {
        string memory newContractURIBase = "https://new-contract-uri.com/";

        vm.expectEmit(false, false, false, true);
        emit SetContractURIBase(DEFAULT_CONTRACT_URI, newContractURIBase);

        vm.prank(controller);
        metadata.setContractURIBase(newContractURIBase);
    }

    function test_controller_can_set_default_collection_owner() public {
        address newDefaultCollectionOwner = mkaddr("new collection owner");

        vm.prank(controller);
        metadata.setDefaultCollectionOwner(newDefaultCollectionOwner);

        assertEq(metadata.defaultCollectionOwner(), newDefaultCollectionOwner);
    }

    function test_non_controller_cannot_set_default_collection_owner() public {
        address newDefaultCollectionOwner = mkaddr("new collection owner");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        metadata.setDefaultCollectionOwner(newDefaultCollectionOwner);
    }

    function test_set_default_collection_owner_emits_event() public {
        address newDefaultCollectionOwner = mkaddr("new collection owner");

        vm.expectEmit(false, false, false, true);
        emit SetDefaultCollectionOwner(owner, newDefaultCollectionOwner);

        vm.prank(controller);
        metadata.setDefaultCollectionOwner(newDefaultCollectionOwner);
    }

    function test_default_collection_owner() public {
        assertEq(metadata.owner(address(1)), metadata.defaultCollectionOwner());
    }

    function test_controller_can_set_collection_owner() public {
        address newCollectionOwner = mkaddr("new collection owner");

        vm.prank(controller);
        metadata.setCollectionOwner(address(1), newCollectionOwner);

        assertEq(metadata.collectionOwners(address(1)), newCollectionOwner);
        assertEq(metadata.owner(address(1)), newCollectionOwner);
    }

    function test_non_controller_cannot_set_collection_owner() public {
        address newCollectionOwner = mkaddr("new collection owner");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        metadata.setCollectionOwner(address(1), newCollectionOwner);
    }

    function test_set_collection_owner_emits_event() public {
        address newCollectionOwner = mkaddr("new collection owner");

        vm.expectEmit(false, false, false, true);
        emit SetCollectionOwner(address(1), newCollectionOwner);

        vm.prank(controller);
        metadata.setCollectionOwner(address(1), newCollectionOwner);
    }

    function test_controller_cannot_set_invalid_dependency() public {
        address invalid = mkaddr("invalid");

        vm.expectRevert(abi.encodeWithSelector(IControllable.InvalidDependency.selector, bytes32("invalid")));
        vm.prank(controller);
        metadata.setDependency("invalid", invalid);
    }

    function test_controller_cannot_set_zero_address() public {
        vm.expectRevert(ICommonErrors.ZeroAddress.selector);
        vm.prank(controller);
        metadata.setDependency("creators", address(0));
    }
}

contract TestCreators is MetadataTest {
    function test_has_creators_address() public {
        assertEq(metadata.creators(), creators);
    }

    function test_creators_can_set_custom_resolver() public {
        vm.prank(creators);
        metadata.setCustomResolver(1, customResolver);

        assertEq(address(metadata.customResolvers(1)), address(customResolver));
    }

    function test_non_creators_cannot_set_custom_resolver() public {
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        metadata.setCustomResolver(1, customResolver);
    }

    function test_set_custom_resolver_emits_event() public {
        vm.expectEmit(true, false, false, true);
        emit SetCustomResolver(1, customResolver);

        vm.prank(creators);
        metadata.setCustomResolver(1, customResolver);
    }

    function test_can_set_custom_uri() public {
        vm.prank(creators);
        metadata.setCustomURI(1, CUSTOM_TOKEN_URI);

        assertEq(metadata.customURIs(1), CUSTOM_TOKEN_URI);
    }

    function test_non_creators_cannot_set_custom_uri() public {
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        metadata.setCustomURI(1, CUSTOM_TOKEN_URI);
    }

    function test_set_custom_uri_emits_event() public {
        vm.expectEmit(true, false, false, true);
        emit SetCustomURI(1, CUSTOM_TOKEN_URI);

        vm.prank(creators);
        metadata.setCustomURI(1, CUSTOM_TOKEN_URI);
    }
}

contract TestMetadata is MetadataTest {
    using Strings for address;

    function test_calls_custom_resolver_when_present() public {
        vm.prank(creators);
        metadata.setCustomResolver(1, customResolver);

        assertEq(metadata.uri(1), CUSTOM_RESOLVER_TOKEN_URI);
    }

    function test_returns_custom_uri_when_present() public {
        vm.prank(creators);
        metadata.setCustomURI(1, CUSTOM_TOKEN_URI);

        assertEq(metadata.uri(1), CUSTOM_TOKEN_URI);
    }

    function test_returns_default_uri_otherwise() public {
        assertEq(metadata.uri(1), string.concat(DEFAULT_TOKEN_URI, "1.json"));
    }

    function test_creator_can_unset_custom_resolver() public {
        vm.prank(creators);
        metadata.setCustomResolver(1, customResolver);

        assertEq(metadata.uri(1), CUSTOM_RESOLVER_TOKEN_URI);

        vm.prank(creators);
        metadata.setCustomResolver(1, IMetadataResolver(address(0)));

        assertEq(metadata.uri(1), string.concat(DEFAULT_TOKEN_URI, "1.json"));
    }

    function test_creator_can_unset_custom_uri() public {
        vm.prank(creators);
        metadata.setCustomURI(1, CUSTOM_TOKEN_URI);

        assertEq(metadata.uri(1), CUSTOM_TOKEN_URI);

        vm.prank(creators);
        metadata.setCustomURI(1, "");

        assertEq(metadata.uri(1), string.concat(DEFAULT_TOKEN_URI, "1.json"));
    }

    function test_returns_contract_metadata_uri() public {
        address _contract = mkaddr("contract");
        assertEq(metadata.contractURI(_contract), string.concat(DEFAULT_CONTRACT_URI, _contract.toHexString(), ".json"));
    }
}

contract TestContractInfo is MetadataTest {
    function test_has_name() public {
        assertEq(metadata.NAME(), "Metadata");
    }

    function test_has_version() public {
        assertEq(metadata.VERSION(), "0.0.1");
    }
}

contract TestPause is MetadataTest {
    function test_is_not_paused_by_default() public {
        assertEq(metadata.paused(), false);
    }

    function test_can_be_paused_by_controller() public {
        vm.prank(controller);
        metadata.pause();

        assertEq(metadata.paused(), true);
    }

    function test_cannot_be_paused_by_non_controller() public {
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        metadata.pause();

        assertEq(metadata.paused(), false);
    }

    function test_can_be_unpaused_by_controller() public {
        vm.prank(controller);
        metadata.pause();

        assertEq(metadata.paused(), true);

        vm.prank(controller);
        metadata.unpause();

        assertEq(metadata.paused(), false);
    }

    function test_cannot_be_unpaused_by_non_controller() public {
        vm.prank(controller);
        metadata.pause();

        assertEq(metadata.paused(), true);

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        metadata.unpause();

        assertEq(metadata.paused(), true);
    }

    function test_cannot_set_custom_uri_when_paused() public {
        vm.prank(controller);
        metadata.pause();

        vm.prank(creators);
        vm.expectRevert("Pausable: paused");
        metadata.setCustomURI(1, CUSTOM_TOKEN_URI);
    }

    function test_cannot_set_custom_resolver_when_paused() public {
        vm.prank(controller);
        metadata.pause();

        vm.prank(creators);
        vm.expectRevert("Pausable: paused");
        metadata.setCustomResolver(1, customResolver);
    }
}
