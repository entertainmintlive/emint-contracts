// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./EmintTest.t.sol";
import "./fakes/FakeResolver.sol";
import "../src/Creators.sol";
import "../src/CreatorAuth.sol";
import "../src/Metadata.sol";
import "../src/Projects.sol";
import "../src/Raises.sol";
import "../src/Tokens.sol";
import "../src/Minter.sol";
import "../src/TokenDeployer.sol";
import "../src/TokenAuth.sol";
import "../src/libraries/codecs/TokenCodec.sol";
import "../src/libraries/codecs/RaiseCodec.sol";
import "../src/interfaces/ICommonErrors.sol";

contract CreatorsTest is EmintTest {
    Metadata internal metadata;
    CreatorAuth internal creatorAuth;
    Projects internal projects;
    Creators internal creators;
    Raises internal raises;
    Tokens internal tokens;
    Minter internal minter;
    TokenDeployer internal deployer;
    TokenAuth internal tokenAuth;

    address alice = mkaddr("alice");
    address bob = mkaddr("bob");
    address carol = mkaddr("carol");
    address eve = mkaddr("eve");

    address controller = mkaddr("controller");
    address royalties = mkaddr("royalties");
    address owner = mkaddr("owner");

    event SetCreatorAuth(address oldCreatorAuth, address newCreatorAuth);
    event SetMetadata(address oldMetadata, address newMetadata);
    event SetRaises(address oldRaises, address newRaises);
    event SetProjects(address oldProjects, address newProjects);

    string constant DEFAULT_CONTRACT_URI = "http://default-uri.com/contract/";
    string constant DEFAULT_TOKEN_URI = "http://default-uri.com/token/";

    TierParams[] tierParams;

    RaiseParams raiseParams = RaiseParams({
        currency: ETH,
        goal: 10 ether,
        max: 20 ether,
        presaleStart: uint64(block.timestamp),
        presaleEnd: uint64(block.timestamp) + 10 days,
        publicSaleStart: uint64(block.timestamp) + 10 days,
        publicSaleEnd: uint64(block.timestamp) + 20 days
    });

    function setUp() public {
        tierParams.push(
            TierParams({tierType: TierType.Fan, supply: 100, price: 0.01 ether, limitPerAddress: 3, allowListRoot: ""})
        );
        tierParams.push(
            TierParams({tierType: TierType.Fan, supply: 10, price: 0.1 ether, limitPerAddress: 3, allowListRoot: ""})
        );
        tierParams.push(
            TierParams({tierType: TierType.Fan, supply: 1, price: 1 ether, limitPerAddress: 1, allowListRoot: ""})
        );
        tierParams.push(
            TierParams({tierType: TierType.Brand, supply: 1, price: 5 ether, limitPerAddress: 1, allowListRoot: ""})
        );
        tierParams.push(
            TierParams({tierType: TierType.Brand, supply: 1, price: 10 ether, limitPerAddress: 1, allowListRoot: ""})
        );

        creatorAuth = new CreatorAuth(controller);
        tokenAuth = new TokenAuth(controller);
        projects = new Projects(controller);
        metadata = new Metadata(controller, DEFAULT_TOKEN_URI, DEFAULT_CONTRACT_URI, owner);
        tokens = new Tokens(controller);
        minter = new Minter(controller);
        deployer = new TokenDeployer(controller);
        creators = new Creators(controller);
        raises = new Raises(controller);

        vm.startPrank(controller);
        metadata.setDependency("creators", address(creators));

        tokens.setDependency("minter", address(minter));
        tokens.setDependency("deployer", address(deployer));
        tokens.setDependency("metadata", address(metadata));
        tokens.setDependency("royalties", royalties);

        minter.setDependency("tokens", address(tokens));
        deployer.setDependency("tokens", address(tokens));

        creators.setDependency("creatorAuth", address(creatorAuth));
        creators.setDependency("metadata", address(metadata));
        creators.setDependency("projects", address(projects));
        creators.setDependency("raises", address(raises));

        raises.setDependency("creators", address(creators));
        raises.setDependency("projects", address(projects));
        raises.setDependency("minter", address(minter));
        raises.setDependency("deployer", address(deployer));
        raises.setDependency("tokens", address(tokens));
        raises.setDependency("tokenAuth", address(tokenAuth));

        minter.allow(address(raises));
        deployer.allow(address(raises));
        projects.allow(address(creators));
        vm.stopPrank();
    }
}

contract TestCreators is CreatorsTest {
    function test_has_creator_auth_address() public {
        assertEq(creators.creatorAuth(), address(creatorAuth));
    }
}

contract TestProjectCreation is CreatorsTest {
    function test_has_projects_address() public {
        assertEq(creators.projects(), address(projects));
    }

    function test_allowed_creator_can_create_new_project() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        vm.prank(alice);
        uint32 projectId = creators.createProject();

        assertEq(projectId, 1);
        assertEq(projects.ownerOf(projectId), alice);
    }

    function test_denied_creator_cannot_create_new_project() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.createProject();
    }
}

contract TestProjectOwnership is CreatorsTest {
    function test_allowed_creator_can_propose_ownership_transfer() public {
        vm.startPrank(controller);
        creatorAuth.allow(alice);
        creatorAuth.allow(bob);
        vm.stopPrank();

        vm.startPrank(alice);
        creators.createProject();
        creators.transferOwnership(1, bob);
        vm.stopPrank();

        assertEq(projects.ownerOf(1), alice);
        assertEq(projects.pendingOwnerOf(1), bob);
    }

    function test_allowed_creator_cannot_propose_ownership_transfer_to_non_creator() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        vm.startPrank(alice);
        creators.createProject();
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.transferOwnership(1, bob);
    }

    function test_pending_owner_can_accept_ownership_transfer() public {
        vm.startPrank(controller);
        creatorAuth.allow(alice);
        creatorAuth.allow(bob);
        vm.stopPrank();

        vm.startPrank(alice);
        creators.createProject();
        creators.transferOwnership(1, bob);
        vm.stopPrank();

        assertEq(projects.ownerOf(1), alice);
        assertEq(projects.pendingOwnerOf(1), bob);

        vm.prank(bob);
        creators.acceptOwnership(1);

        assertEq(projects.ownerOf(1), bob);
    }

    function test_denied_creator_cannot_initiate_transfer() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.transferOwnership(1, eve);
    }

    function test_denied_creator_cannot_accept_transfer() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.acceptOwnership(1);
    }

    function test_non_owner_cannot_initiate_transfer() public {
        vm.startPrank(controller);
        creatorAuth.allow(alice);
        creatorAuth.allow(bob);
        vm.stopPrank();

        vm.prank(alice);
        creators.createProject();

        vm.prank(bob);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.transferOwnership(1, bob);
    }

    function test_non_pending_owner_cannot_accept_transfer() public {
        vm.startPrank(controller);
        creatorAuth.allow(alice);
        creatorAuth.allow(bob);
        creatorAuth.allow(carol);
        vm.stopPrank();

        vm.startPrank(alice);
        creators.createProject();
        creators.transferOwnership(1, bob);
        vm.stopPrank();

        vm.prank(carol);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.acceptOwnership(1);
    }
}

contract TestRaises is CreatorsTest {
    function test_has_raises_address() public {
        assertEq(creators.raises(), address(raises));
    }

    function test_allowed_creator_can_create_new_raise() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        vm.startPrank(alice);
        uint32 projectId = creators.createProject();
        uint32 raiseId = creators.createRaise(projectId, raiseParams, tierParams);

        assertEq(raiseId, 1);
        Raise memory raise = raises.getRaise(projectId, raiseId);
        assertEq(raise.raiseId, 1);
    }

    function test_denied_creator_cannot_create_new_raise() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.createRaise(1, raiseParams, tierParams);
    }

    function test_allowed_creator_cannot_create_raise_for_nonexistent_project() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        vm.prank(alice);
        vm.expectRevert(ICommonErrors.NotFound.selector);
        creators.createRaise(1, raiseParams, tierParams);
    }

    function test_allowed_creator_cannot_create_raise_for_unowned_project() public {
        vm.startPrank(controller);
        creatorAuth.allow(alice);
        creatorAuth.allow(bob);
        vm.stopPrank();

        vm.startPrank(alice);
        uint32 projectId = creators.createProject();
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.createRaise(projectId, raiseParams, tierParams);
    }

    function test_project_owner_can_cancel_raise() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        vm.startPrank(alice);
        uint32 projectId = creators.createProject();
        uint32 raiseId = creators.createRaise(projectId, raiseParams, tierParams);
        creators.cancelRaise(projectId, raiseId);

        Raise memory raise = raises.getRaise(projectId, raiseId);
        assertEq(uint8(raise.state), uint8(RaiseState.Cancelled));
    }

    function test_denied_creator_cannot_cancel_raise() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.cancelRaise(1, 1);
    }

    function test_non_owner_cannot_cancel_raise() public {
        vm.startPrank(controller);
        creatorAuth.allow(alice);
        creatorAuth.allow(bob);
        vm.stopPrank();

        vm.startPrank(alice);
        uint32 projectId = creators.createProject();
        uint32 raiseId = creators.createRaise(projectId, raiseParams, tierParams);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.cancelRaise(projectId, raiseId);
    }

    function test_project_owner_can_close_raise() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        vm.startPrank(alice);
        uint32 projectId = creators.createProject();
        uint32 raiseId = creators.createRaise(projectId, raiseParams, tierParams);
        vm.stopPrank();

        Raise memory raise = raises.getRaise(projectId, raiseId);
        vm.warp(raise.publicSaleStart);

        deal(bob, 20 ether);
        vm.prank(bob);
        raises.mint{value: 10 ether}(projectId, raiseId, 4, 1);

        vm.prank(alice);
        creators.closeRaise(projectId, raiseId);
        raise = raises.getRaise(projectId, raiseId);
        assertEq(uint8(raise.state), uint8(RaiseState.Funded));
    }

    function test_denied_creator_cannot_close_raise() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.closeRaise(1, 1);
    }

    function test_non_owner_cannot_close_raise() public {
        vm.startPrank(controller);
        creatorAuth.allow(alice);
        creatorAuth.allow(bob);
        vm.stopPrank();

        vm.startPrank(alice);
        uint32 projectId = creators.createProject();
        uint32 raiseId = creators.createRaise(projectId, raiseParams, tierParams);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.closeRaise(projectId, raiseId);
    }

    function test_project_owner_can_withdraw_raise_funds() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        vm.startPrank(alice);
        uint32 projectId = creators.createProject();
        uint32 raiseId = creators.createRaise(projectId, raiseParams, tierParams);
        vm.stopPrank();

        Raise memory raise = raises.getRaise(projectId, raiseId);
        vm.warp(raise.publicSaleStart);

        deal(bob, 20 ether);
        vm.prank(bob);
        raises.mint{value: 10 ether}(projectId, raiseId, 4, 1);

        vm.startPrank(alice);
        creators.closeRaise(projectId, raiseId);
        creators.withdrawRaiseFunds(projectId, raiseId, alice);
        vm.stopPrank();
        assertEq(address(alice).balance, 7.5 ether);
    }

    function test_denied_creator_cannot_withdraw_raise_funds() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.withdrawRaiseFunds(1, 1, eve);
    }

    function test_non_owner_cannot_withdraw_raise_funds() public {
        vm.startPrank(controller);
        creatorAuth.allow(alice);
        creatorAuth.allow(bob);
        vm.stopPrank();

        vm.startPrank(alice);
        uint32 projectId = creators.createProject();
        uint32 raiseId = creators.createRaise(projectId, raiseParams, tierParams);
        vm.stopPrank();

        Raise memory raise = raises.getRaise(projectId, raiseId);
        vm.warp(raise.publicSaleStart);

        deal(bob, 20 ether);
        vm.prank(bob);
        raises.mint{value: 10 ether}(projectId, raiseId, 4, 1);

        vm.prank(alice);
        creators.closeRaise(projectId, raiseId);

        vm.prank(bob);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.withdrawRaiseFunds(projectId, raiseId, bob);
    }
}

contract TestProjectMetadata is CreatorsTest {
    function test_has_metadata_address() public {
        assertEq(creators.metadata(), address(metadata));
    }

    function test_project_owner_can_set_custom_uri() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        vm.prank(alice);
        creators.createProject();

        string memory newURI = "http://new-custom-uri.com/{id}";

        bytes30 tokenData = RaiseCodec.encode(RaiseData({tierType: TierType.Fan, tierId: 0, raiseId: 0, projectId: 1}));
        uint256 tokenId =
            TokenCodec.encode(TokenData({tokenType: TokenType.Raise, encodingVersion: 0, data: tokenData}));

        vm.prank(alice);
        creators.setCustomURI(tokenId, newURI);

        assertEq(metadata.customURIs(tokenId), newURI);
    }

    function test_non_project_owner_cannot_set_custom_uri() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        vm.prank(controller);
        creatorAuth.allow(eve);

        vm.prank(alice);
        uint32 projectId = creators.createProject();

        string memory newURI = "http://new-custom-uri.com/{id}";

        bytes30 tokenData =
            RaiseCodec.encode(RaiseData({tierType: TierType.Fan, tierId: 0, raiseId: 0, projectId: projectId}));
        uint256 tokenId =
            TokenCodec.encode(TokenData({tokenType: TokenType.Raise, encodingVersion: 0, data: tokenData}));

        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.setCustomURI(tokenId, newURI);
    }

    function test_denied_creator_cannot_set_custom_uri() public {
        string memory newURI = "http://new-custom-uri.com/{id}";

        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.setCustomURI(1, newURI);
    }

    function test_project_owner_can_set_custom_resolver() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        vm.prank(alice);
        uint32 projectId = creators.createProject();

        IMetadataResolver customResolver = new FakeResolver(
      'http://custom-resolver.com/{id}'
    );

        bytes30 tokenData =
            RaiseCodec.encode(RaiseData({tierType: TierType.Fan, tierId: 0, raiseId: 0, projectId: projectId}));
        uint256 tokenId =
            TokenCodec.encode(TokenData({tokenType: TokenType.Raise, encodingVersion: 0, data: tokenData}));

        vm.prank(alice);
        creators.setCustomResolver(tokenId, customResolver);

        assertEq(address(metadata.customResolvers(tokenId)), address(customResolver));
    }

    function test_non_project_owner_cannot_set_custom_resolver() public {
        vm.prank(controller);
        creatorAuth.allow(alice);

        vm.prank(controller);
        creatorAuth.allow(eve);

        vm.prank(alice);
        uint32 projectId = creators.createProject();

        IMetadataResolver customResolver = new FakeResolver(
      'http://custom-resolver.com/{id}'
    );

        bytes30 tokenData =
            RaiseCodec.encode(RaiseData({tierType: TierType.Fan, tierId: 0, raiseId: 0, projectId: projectId}));
        uint256 tokenId =
            TokenCodec.encode(TokenData({tokenType: TokenType.Raise, encodingVersion: 0, data: tokenData}));

        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.setCustomResolver(tokenId, customResolver);
    }

    function test_denied_creator_cannot_set_custom_resolver() public {
        IMetadataResolver customResolver = new FakeResolver(
      'http://custom-resolver.com/{id}'
    );

        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.setCustomResolver(1, customResolver);
    }
}

contract TestController is CreatorsTest {
    function test_has_controller_address() public {
        assertEq(creators.controller(), controller);
    }

    function test_controller_can_set_creator_auth() public {
        address newCreatorAuth = mkaddr("new creator auth");

        vm.prank(controller);
        creators.setDependency("creatorAuth", newCreatorAuth);

        assertEq(creators.creatorAuth(), newCreatorAuth);
    }

    function test_non_controller_cannot_set_creator_auth() public {
        address newCreatorAuth = mkaddr("new creator auth");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.setDependency("creatorAuth", newCreatorAuth);
    }

    function test_set_creator_auth_emits_event() public {
        address newCreatorAuth = mkaddr("new creator auth");

        vm.expectEmit(false, false, false, true);
        emit SetCreatorAuth(address(creatorAuth), newCreatorAuth);

        vm.prank(controller);
        creators.setDependency("creatorAuth", newCreatorAuth);
    }

    function test_controller_can_set_metadata() public {
        address newMetadata = mkaddr("new metadata");

        vm.prank(controller);
        creators.setDependency("metadata", newMetadata);

        assertEq(creators.metadata(), newMetadata);
    }

    function test_non_controller_cannot_set_metadata() public {
        address newMetadata = mkaddr("new metadata");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.setDependency("metadata", newMetadata);
    }

    function test_set_metadata_emits_event() public {
        address newMetadata = mkaddr("new metadata");

        vm.expectEmit(false, false, false, true);
        emit SetMetadata(address(metadata), newMetadata);

        vm.prank(controller);
        creators.setDependency("metadata", newMetadata);
    }

    function test_controller_can_set_raises() public {
        address newRaises = mkaddr("new raises");

        vm.prank(controller);
        creators.setDependency("raises", newRaises);

        assertEq(creators.raises(), newRaises);
    }

    function test_non_controller_cannot_set_raises() public {
        address newRaises = mkaddr("new raises");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.setDependency("raises", newRaises);
    }

    function test_set_raises_emits_event() public {
        address newRaises = mkaddr("new raises");

        vm.expectEmit(false, false, false, true);
        emit SetRaises(address(raises), newRaises);

        vm.prank(controller);
        creators.setDependency("raises", newRaises);
    }

    function test_controller_can_set_projects() public {
        address newProjects = mkaddr("new projects");

        vm.prank(controller);
        creators.setDependency("projects", newProjects);

        assertEq(creators.projects(), newProjects);
    }

    function test_non_controller_cannot_set_projects() public {
        address newProjects = mkaddr("new projects");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        creators.setDependency("projects", newProjects);
    }

    function test_set_projects_emits_event() public {
        address newProjects = mkaddr("new projects");

        vm.expectEmit(false, false, false, true);
        emit SetProjects(address(projects), newProjects);

        vm.prank(controller);
        creators.setDependency("projects", newProjects);
    }
}

contract TestContractInfo is CreatorsTest {
    function test_has_name() public {
        assertEq(creators.NAME(), "Creators");
    }

    function test_has_version() public {
        assertEq(creators.VERSION(), "0.0.1");
    }
}
