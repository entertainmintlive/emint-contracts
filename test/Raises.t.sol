// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./EmintTest.t.sol";
import {ETH} from "../src/constants/Constants.sol";
import {Tier} from "../src/structs/Tier.sol";
import {Raise} from "../src/structs/Raise.sol";
import "../src/interfaces/ICommonErrors.sol";
import "../src/libraries/validators/RaiseValidator.sol";
import "../src/Projects.sol";
import "../src/Raises.sol";
import "../src/Tokens.sol";
import "../src/Minter.sol";
import "../src/TokenDeployer.sol";
import "../src/TokenAuth.sol";
import {FakeERC20} from "./fakes/FakeERC20.sol";

contract RaisesTest is EmintTest {
    Projects internal projects;
    Raises internal raises;
    Tokens internal tokens;
    Minter internal minter;
    TokenDeployer internal deployer;
    TokenAuth internal tokenAuth;
    FakeERC20 internal erc20;

    address creators = mkaddr("creators");
    address controller = mkaddr("controller");
    address metadata = mkaddr("metadata");
    address royalties = mkaddr("royalties");

    address alice = mkaddr("alice");
    address bob = mkaddr("bob");
    address carol = mkaddr("carol");
    address dan = mkaddr("dan");

    address protocol = mkaddr("protocol");

    event CreateRaise(uint32 indexed projectId, uint32 raiseId, RaiseParams params, TierParams[] tiers);
    event UpdateRaise(uint32 indexed projectId, uint32 indexed raiseId, RaiseParams params, TierParams[] tiers);
    event Mint(
        uint32 indexed projectId,
        uint32 indexed raiseID,
        uint32 indexed tierId,
        address minter,
        uint256 amount,
        bytes32[] proof
    );
    event SettleRaise(uint32 indexed projectId, uint32 indexed raiseId, RaiseState newState);
    event CancelRaise(uint32 indexed projectId, uint32 indexed raiseId, RaiseState newState);
    event CloseRaise(uint32 indexed projectId, uint32 indexed raiseId, RaiseState newState);
    event WithdrawRaiseFunds(
        uint32 indexed projectId, uint32 indexed raiseId, address indexed receiver, address currency, uint256 amount
    );
    event Redeem(
        uint32 indexed projectId,
        uint32 indexed raiseID,
        uint32 indexed tierId,
        address receiver,
        uint256 tokenAmount,
        address owner,
        uint256 refundAmount
    );
    event WithdrawFees(address indexed receiver, address currency, uint256 amount);

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

    // Merkle root of allowlist including alice, bob, carol, and dan
    bytes32 internal constant MERKLE_ROOT = bytes32(0x8c4e171e3dc2c695c52b4b12c93bb70ba48d5f27adebcbb0267e9bf720c47469);

    function setUp() public virtual {
        tierParams.push(
            TierParams({
                tierType: TierType.Fan,
                supply: 100,
                price: 0.01 ether,
                limitPerAddress: 3,
                allowListRoot: MERKLE_ROOT
            })
        );
        tierParams.push(
            TierParams({
                tierType: TierType.Fan,
                supply: 10,
                price: 0.1 ether,
                limitPerAddress: 3,
                allowListRoot: MERKLE_ROOT
            })
        );
        tierParams.push(
            TierParams({
                tierType: TierType.Fan,
                supply: 1,
                price: 1 ether,
                limitPerAddress: 1,
                allowListRoot: MERKLE_ROOT
            })
        );
        tierParams.push(
            TierParams({
                tierType: TierType.Brand,
                supply: 1,
                price: 5 ether,
                limitPerAddress: 1,
                allowListRoot: MERKLE_ROOT
            })
        );
        tierParams.push(
            TierParams({
                tierType: TierType.Brand,
                supply: 1,
                price: 10 ether,
                limitPerAddress: 1,
                allowListRoot: MERKLE_ROOT
            })
        );

        vm.startPrank(controller);
        erc20 = new FakeERC20();
        projects = new Projects(controller);

        minter = new Minter(controller);
        deployer = new TokenDeployer(controller);
        tokens = new Tokens(controller);

        minter.setDependency("tokens", address(tokens));
        deployer.setDependency("tokens", address(tokens));

        tokens.setDependency("minter", address(minter));
        tokens.setDependency("deployer", address(deployer));
        tokens.setDependency("metadata", metadata);
        tokens.setDependency("royalties", royalties);

        tokenAuth = new TokenAuth(controller);

        raises = new Raises(controller);
        raises.setDependency("creators", creators);
        raises.setDependency("projects", address(projects));
        raises.setDependency("minter", address(minter));
        raises.setDependency("deployer", address(deployer));
        raises.setDependency("tokens", address(tokens));
        raises.setDependency("tokenAuth", address(tokenAuth));

        minter.allow(address(raises));
        deployer.allow(address(raises));
        projects.allow(address(creators));
        projects.allow(address(this));
        tokenAuth.allow(address(erc20));
        vm.stopPrank();
    }
}

contract TestRaises is RaisesTest {
    function test_has_creators_address() public {
        assertEq(raises.creators(), creators);
    }

    function test_has_projects_address() public {
        assertEq(raises.projects(), address(projects));
    }
}

contract TestCreateRaise is RaisesTest {
    function test_only_creators_can_create_raise() public {
        projects.create(address(this));

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.create(1, raiseParams, tierParams);

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);

        assertEq(raise.projectId, 1);
        assertEq(raise.raiseId, 1);
    }

    function test_create_raise_emits_event() public {
        projects.create(address(this));

        vm.expectEmit(true, false, false, true);
        emit CreateRaise(1, 1, raiseParams, tierParams);

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);
    }

    function test_raise_has_tiers() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Tier[] memory tiers = raises.getTiers(1, 1);

        assertEq(tiers.length, 5);
        assertEq(tiers[0].price, 0.01 ether);
        assertEq(tiers[1].price, 0.1 ether);
        assertEq(tiers[2].price, 1 ether);
        assertEq(tiers[3].price, 5 ether);
        assertEq(tiers[4].price, 10 ether);
        assertEq(tiers[0].supply, 100);
        assertEq(tiers[1].supply, 10);
        assertEq(tiers[2].supply, 1);
        assertEq(tiers[3].supply, 1);
        assertEq(tiers[4].supply, 1);
    }

    function test_tier_supply_must_be_nonzero() public {
        projects.create(address(this));
        tierParams[1].supply = 0;

        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "zero supply"));
        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);
    }

    function test_raise_has_goal() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);

        assertEq(raise.goal, raiseParams.goal);
    }

    function test_raise_has_max() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);

        assertEq(raise.max, raiseParams.max);
    }

    function test_max_must_be_greater_than_or_equal_to_goal() public {
        projects.create(address(this));

        vm.prank(creators);
        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "max < goal"));
        raises.create(
            1,
            RaiseParams({
                currency: ETH,
                goal: 10 ether,
                max: 1 ether,
                presaleStart: uint64(block.timestamp),
                presaleEnd: uint64(block.timestamp) + 10 days,
                publicSaleStart: uint64(block.timestamp) + 10 days,
                publicSaleEnd: uint64(block.timestamp) + 20 days
            }),
            tierParams
        );

        vm.prank(creators);
        raises.create(
            1,
            RaiseParams({
                currency: ETH,
                goal: 10 ether,
                max: 10 ether,
                presaleStart: uint64(block.timestamp),
                presaleEnd: uint64(block.timestamp) + 10 days,
                publicSaleStart: uint64(block.timestamp) + 10 days,
                publicSaleEnd: uint64(block.timestamp) + 20 days
            }),
            tierParams
        );
        Raise memory raise = raises.getRaise(1, 1);
        assertEq(raise.goal, 10 ether);
        assertEq(raise.max, 10 ether);
    }

    function test_raise_has_presale_start() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);

        assertEq(raise.presaleStart, raiseParams.presaleStart);
    }

    function test_raise_has_presale_end() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);

        assertEq(raise.presaleEnd, raiseParams.presaleEnd);
    }

    function test_raise_has_public_sale_start() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);

        assertEq(raise.publicSaleStart, raiseParams.publicSaleStart);
    }

    function test_raise_has_public_sale_end() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);

        assertEq(raise.publicSaleEnd, raiseParams.publicSaleEnd);
    }

    function test_end_must_be_later_than_start() public {
        projects.create(address(this));

        raiseParams.presaleStart = uint64(block.timestamp) + 1;
        raiseParams.presaleEnd = uint64(block.timestamp);

        vm.prank(creators);
        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "end < start"));
        raises.create(1, raiseParams, tierParams);
    }

    function test_duration_must_be_less_than_one_year() public {
        projects.create(address(this));

        raiseParams.publicSaleEnd = raiseParams.publicSaleEnd + 365 days;

        vm.prank(creators);
        vm.expectRevert(abi.encodeWithSelector(ValidationError.selector, "too long"));
        raises.create(1, raiseParams, tierParams);
    }

    function test_state_is_active() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.state), uint8(RaiseState.Active));
    }

    function test_max_may_be_zero_to_indicate_no_max() public {
        projects.create(address(this));

        raiseParams.max = 0;

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(raise.max, 0);
    }

    function test_amount_raised_starts_at_zero() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);

        assertEq(raise.raised, 0);
    }

    function test_balance_starts_at_zero() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);

        assertEq(raise.balance, 0);
    }

    function test_reverts_if_project_does_not_exist() public {
        vm.expectRevert(ICommonErrors.NotFound.selector);
        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);
    }

    function test_new_raise_increments_raise_id() public {
        projects.create(address(this));

        assertEq(raises.totalRaises(1), 0);

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        assertEq(raises.totalRaises(1), 1);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(raise.raiseId, 1);

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        assertEq(raises.totalRaises(1), 2);

        raise = raises.getRaise(1, 2);
        assertEq(raise.raiseId, 2);
    }

    function test_get_raise_struct() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(raise.projectId, 1);
        assertEq(raise.raiseId, 1);
        assertEq(raise.goal, raiseParams.goal);
        assertEq(raise.raised, 0);
        assertEq(raise.balance, 0);
    }
}

contract TestUpdateRaise is RaisesTest {
    using Phases for Raise;

    function test_creators_can_update_raise_when_scheduled() public {
        projects.create(address(this));
        raiseParams.presaleStart = uint64(block.timestamp) + 5 days;

        vm.prank(controller);
        tokenAuth.allow(address(erc20));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.phase()), uint8(Phase.Scheduled));

        RaiseParams memory updatedParams = RaiseParams({
            currency: address(erc20),
            goal: 22 ether,
            max: 50 ether,
            presaleStart: uint64(block.timestamp) + 10 days,
            presaleEnd: uint64(block.timestamp) + 20 days,
            publicSaleStart: uint64(block.timestamp) + 30 days,
            publicSaleEnd: uint64(block.timestamp) + 40 days
        });
        TierParams[] memory updatedTierParams = new TierParams[](5);
        updatedTierParams[0] = TierParams({
            tierType: TierType.Fan,
            supply: 200,
            price: 0.02 ether,
            limitPerAddress: 3,
            allowListRoot: MERKLE_ROOT
        });
        updatedTierParams[1] = TierParams({
            tierType: TierType.Fan,
            supply: 20,
            price: 0.2 ether,
            limitPerAddress: 3,
            allowListRoot: MERKLE_ROOT
        });
        updatedTierParams[2] = TierParams({
            tierType: TierType.Fan,
            supply: 2,
            price: 2 ether,
            limitPerAddress: 1,
            allowListRoot: MERKLE_ROOT
        });
        updatedTierParams[3] = TierParams({
            tierType: TierType.Brand,
            supply: 2,
            price: 10 ether,
            limitPerAddress: 1,
            allowListRoot: MERKLE_ROOT
        });
        updatedTierParams[4] = TierParams({
            tierType: TierType.Brand,
            supply: 2,
            price: 20 ether,
            limitPerAddress: 1,
            allowListRoot: MERKLE_ROOT
        });

        vm.prank(creators);
        raises.update(1, 1, updatedParams, updatedTierParams);

        Raise memory updated = raises.getRaise(1, 1);
        assertEq(updated.currency, updatedParams.currency);
        assertEq(updated.goal, updatedParams.goal);
        assertEq(updated.max, updatedParams.max);
        assertEq(updated.presaleStart, updatedParams.presaleStart);
        assertEq(updated.presaleEnd, updatedParams.presaleEnd);
        assertEq(updated.publicSaleStart, updatedParams.publicSaleStart);
        assertEq(updated.publicSaleEnd, updatedParams.publicSaleEnd);
        assertEq(updated.projectId, 1);
        assertEq(updated.raiseId, 1);

        Tier[] memory updatedTiers = raises.getTiers(1, 1);
        for (uint256 i; i < updatedTiers.length; i++) {
            Tier memory updatedTier = updatedTiers[i];
            assertEq(uint8(updatedTier.tierType), uint8(updatedTierParams[i].tierType));
            assertEq(updatedTier.supply, updatedTierParams[i].supply);
            assertEq(updatedTier.price, updatedTierParams[i].price);
            assertEq(updatedTier.limitPerAddress, updatedTierParams[i].limitPerAddress);
            assertEq(updatedTier.allowListRoot, updatedTierParams[i].allowListRoot);
        }
    }

    function test_update_raise_emits_event() public {
        projects.create(address(this));
        raiseParams.presaleStart = uint64(block.timestamp) + 5 days;

        vm.prank(controller);
        tokenAuth.allow(address(erc20));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.phase()), uint8(Phase.Scheduled));

        RaiseParams memory updatedParams = RaiseParams({
            currency: address(erc20),
            goal: 22 ether,
            max: 50 ether,
            presaleStart: uint64(block.timestamp) + 10 days,
            presaleEnd: uint64(block.timestamp) + 20 days,
            publicSaleStart: uint64(block.timestamp) + 30 days,
            publicSaleEnd: uint64(block.timestamp) + 40 days
        });
        TierParams[] memory updatedTierParams = new TierParams[](5);
        updatedTierParams[0] = TierParams({
            tierType: TierType.Fan,
            supply: 200,
            price: 0.02 ether,
            limitPerAddress: 3,
            allowListRoot: MERKLE_ROOT
        });
        updatedTierParams[1] = TierParams({
            tierType: TierType.Fan,
            supply: 20,
            price: 0.2 ether,
            limitPerAddress: 3,
            allowListRoot: MERKLE_ROOT
        });
        updatedTierParams[2] = TierParams({
            tierType: TierType.Fan,
            supply: 2,
            price: 2 ether,
            limitPerAddress: 1,
            allowListRoot: MERKLE_ROOT
        });
        updatedTierParams[3] = TierParams({
            tierType: TierType.Brand,
            supply: 2,
            price: 10 ether,
            limitPerAddress: 1,
            allowListRoot: MERKLE_ROOT
        });
        updatedTierParams[4] = TierParams({
            tierType: TierType.Brand,
            supply: 2,
            price: 20 ether,
            limitPerAddress: 1,
            allowListRoot: MERKLE_ROOT
        });

        vm.expectEmit(true, true, false, true);
        emit UpdateRaise(1, 1, updatedParams, updatedTierParams);

        vm.prank(creators);
        raises.update(1, 1, updatedParams, updatedTierParams);
    }

    function test_creators_cannot_update_raise_when_not_scheduled() public {
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.phase()), uint8(Phase.Presale));

        vm.prank(creators);
        vm.expectRevert(IRaises.RaiseNotScheduled.selector);
        raises.update(1, 1, raiseParams, tierParams);
    }

    function test_update_raise_reverts_nonexistent_raise() public {
        projects.create(address(this));

        vm.prank(creators);
        vm.expectRevert(ICommonErrors.NotFound.selector);
        raises.update(1, 1, raiseParams, tierParams);
    }

    function test_update_raise_reverts_nonexistent_project() public {
        vm.prank(creators);
        vm.expectRevert(ICommonErrors.NotFound.selector);
        raises.update(1, 1, raiseParams, tierParams);
    }
}

contract TestMintFromRaise is RaisesTest {
    function setUp() public override {
        super.setUp();
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        deal(alice, 1 ether);
        deal(bob, 15 ether);

        vm.warp(raiseParams.publicSaleStart);
    }

    function test_mint_from_raise() public {
        vm.prank(alice);
        uint256 tokenId = raises.mint{value: 0.01 ether}(1, 1, 0, 1);

        assertEq(tokens.token(tokenId).balanceOf(alice, tokenId), 1);
    }

    function test_mint_from_raise_emits_event() public {
        vm.expectEmit(true, true, true, true);
        emit Mint(1, 1, 0, alice, 1, new bytes32[](0));

        vm.prank(alice);
        raises.mint{value: 0.01 ether}(1, 1, 0, 1);
    }

    function test_mint_from_raise_stores_amount_raised() public {
        vm.prank(alice);
        raises.mint{value: 0.01 ether}(1, 1, 0, 1);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(raise.raised, 0.01 ether);

        vm.prank(alice);
        raises.mint{value: 0.02 ether}(1, 1, 0, 2);

        raise = raises.getRaise(1, 1);
        assertEq(raise.raised, 0.03 ether);

        vm.prank(alice);
        raises.mint{value: 0.3 ether}(1, 1, 1, 3);

        raise = raises.getRaise(1, 1);
        assertEq(raise.raised, 0.33 ether);
    }

    function test_mint_from_raise_increases_balances() public {
        // Alice mints fan tokens (5% protocol fee)
        vm.prank(alice);
        raises.mint{value: 0.01 ether}(1, 1, 0, 1);

        Raise memory raise = raises.getRaise(1, 1);
        uint256 expectedBalance = 0.0095 ether;
        uint256 expectedFees = 0.0005 ether;
        assertEq(raise.balance, expectedBalance);
        assertEq(raise.fees, expectedFees);

        vm.prank(alice);
        raises.mint{value: 0.02 ether}(1, 1, 0, 2);

        expectedBalance = raise.balance + 0.019 ether;
        expectedFees = raise.fees + 0.001 ether;
        raise = raises.getRaise(1, 1);
        assertEq(raise.balance, expectedBalance);
        assertEq(raise.fees, expectedFees);

        vm.prank(alice);
        raises.mint{value: 0.3 ether}(1, 1, 1, 3);

        expectedBalance = raise.balance + 0.285 ether;
        expectedFees = raise.fees + 0.015 ether;
        raise = raises.getRaise(1, 1);
        assertEq(raise.balance, expectedBalance);
        assertEq(raise.fees, expectedFees);

        // Bob mints brand tokens (25% protocol fee)
        vm.prank(bob);
        raises.mint{value: 5 ether}(1, 1, 3, 1);

        expectedBalance = raise.balance + 3.75 ether;
        expectedFees = raise.fees + 1.25 ether;
        raise = raises.getRaise(1, 1);
        assertEq(raise.balance, expectedBalance);
        assertEq(raise.fees, expectedFees);

        vm.prank(bob);
        raises.mint{value: 10 ether}(1, 1, 4, 1);

        expectedBalance = raise.balance + 7.5 ether;
        expectedFees = raise.fees + 2.5 ether;
        raise = raises.getRaise(1, 1);
        assertEq(raise.balance, expectedBalance);
        assertEq(raise.fees, expectedFees);
    }

    function test_mint_from_raise_increments_tier_minted() public {
        vm.prank(alice);
        raises.mint{value: 0.01 ether}(1, 1, 0, 1);

        Tier[] memory tiers = raises.getTiers(1, 1);
        assertEq(tiers[0].minted, 1);

        vm.prank(alice);
        raises.mint{value: 0.02 ether}(1, 1, 0, 2);

        tiers = raises.getTiers(1, 1);
        assertEq(tiers[0].minted, 3);

        vm.prank(alice);
        raises.mint{value: 0.3 ether}(1, 1, 1, 3);

        tiers = raises.getTiers(1, 1);
        assertEq(tiers[1].minted, 3);
    }

    function test_mint_from_raise_above_limit_reverts_minted_maximum() public {
        vm.startPrank(alice);
        raises.mint{value: 0.01 ether}(1, 1, 0, 1);
        raises.mint{value: 0.01 ether}(1, 1, 0, 1);
        raises.mint{value: 0.01 ether}(1, 1, 0, 1);

        vm.expectRevert(IRaises.AddressMintedMaximum.selector);
        raises.mint{value: 0.01 ether}(1, 1, 0, 1);

        vm.stopPrank();
    }

    function test_mint_from_raise_invalid_proof_reverts_invalid_proof() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = "invalid proof";

        vm.warp(raiseParams.presaleStart);
        vm.expectRevert(IRaises.InvalidProof.selector);
        raises.mint{value: 0.01 ether}(1, 1, 0, 1, proof);
    }

    function test_mint_from_raise_valid_proof() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = bytes32(0x21701b7f50c7cbccf1b31875000f6efbcc30a00e9604fcffbef8ce4766d3d99c);
        proof[1] = bytes32(0xa5841a0f2cac2e978a04f8ae468575471188376525061fedcef8e58c4abef025);

        vm.warp(raiseParams.presaleStart);

        vm.prank(alice);
        uint256 tokenId = raises.mint{value: 0.01 ether}(1, 1, 0, 1, proof);
        assertEq(tokens.token(tokenId).balanceOf(alice, tokenId), 1);
    }

    function test_mint_from_raise_insufficient_payment_reverts_invalid_price() public {
        vm.expectRevert(IRaises.InvalidPaymentAmount.selector);
        vm.prank(alice);
        raises.mint(1, 1, 0, 1);
    }

    function test_mint_invalid_project_reverts_not_found() public {
        vm.expectRevert(ICommonErrors.NotFound.selector);
        vm.prank(alice);
        raises.mint{value: 0.01 ether}(0, 1, 0, 1);
    }

    function test_mint_invalid_raise_reverts_not_found() public {
        vm.expectRevert(ICommonErrors.NotFound.selector);
        vm.prank(alice);
        raises.mint{value: 0.01 ether}(1, 0, 0, 1);
    }

    function test_mint_invalid_tier_reverts_not_found() public {
        vm.expectRevert(ICommonErrors.NotFound.selector);
        vm.prank(alice);
        raises.mint{value: 0.01 ether}(1, 1, 5, 1);
    }

    function test_mint_before_start_reverts_raise_inactive() public {
        raiseParams.presaleStart = uint64(block.timestamp) + 1 days;
        raiseParams.presaleEnd = uint64(block.timestamp) + 2 days;
        raiseParams.publicSaleStart = uint64(block.timestamp) + 3 days;
        raiseParams.publicSaleEnd = uint64(block.timestamp) + 4 days;

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        vm.expectRevert(IRaises.RaiseNotStarted.selector);
        vm.prank(alice);
        raises.mint{value: 0.01 ether}(1, 2, 0, 1);
    }

    function test_mint_fully_minted_reverts_with_sold_out() public {
        deal(alice, 2 ether);

        vm.startPrank(alice);

        raises.mint{value: 1 ether}(1, 1, 2, 1);

        vm.expectRevert(IRaises.RaiseSoldOut.selector);
        raises.mint{value: 1 ether}(1, 1, 2, 1);

        vm.stopPrank();
    }

    function test_mint_payment_over_raise_max_reverts_exceeds_max() public {
        vm.warp(0);
        raiseParams.goal = 0.01 ether;
        raiseParams.max = 0.01 ether;

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        vm.warp(raiseParams.publicSaleStart);

        vm.prank(alice);
        raises.mint{value: 0.01 ether}(1, 2, 0, 1);

        vm.expectRevert(IRaises.ExceedsRaiseMaximum.selector);
        vm.prank(alice);
        raises.mint{value: 0.01 ether}(1, 2, 0, 1);
    }

    function test_mint_payment_handles_unlimited_max() public {
        vm.warp(0);
        raiseParams.goal = 0.01 ether;
        raiseParams.max = 0; // Indicates no maximum

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        vm.warp(raiseParams.publicSaleStart);

        // Should not revert with ExceedsMax
        vm.prank(alice);
        raises.mint{value: 0.01 ether}(1, 2, 0, 1);
    }

    function test_mint_after_end_reverts_mint_ended() public {
        vm.warp(raiseParams.publicSaleEnd + 1);
        vm.expectRevert(IRaises.RaiseEnded.selector);
        vm.prank(alice);
        raises.mint{value: 0.01 ether}(1, 1, 0, 1);
    }

    function test_mint_with_erc20() public {
        vm.warp(0);
        raiseParams.currency = address(erc20);

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);
        vm.warp(raiseParams.publicSaleStart);

        erc20.mint(alice, 0.01 ether);
        assertEq(erc20.balanceOf(alice), 0.01 ether);

        vm.startPrank(alice);
        erc20.approve(address(raises), 0.01 ether);
        uint256 tokenId = raises.mint(1, 2, 0, 1);
        vm.stopPrank();

        assertEq(tokens.token(tokenId).balanceOf(alice, tokenId), 1);
        assertEq(erc20.balanceOf(alice), 0);
    }

    function test_mint_with_erc20_sending_value_reverts_with_invalid_price() public {
        vm.warp(0);
        raiseParams.currency = address(erc20);

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);
        vm.warp(raiseParams.publicSaleStart);

        erc20.mint(alice, 0.01 ether);
        assertEq(erc20.balanceOf(alice), 0.01 ether);

        vm.startPrank(alice);
        erc20.approve(address(raises), 0.01 ether);

        vm.expectRevert(IRaises.InvalidPaymentAmount.selector);
        raises.mint{value: 0.01 ether}(1, 2, 0, 1);

        vm.stopPrank();
    }

    function test_mint_with_erc20_denied_token_reverts_with_invalid_currency() public {
        vm.warp(0);
        raiseParams.currency = address(erc20);

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);
        vm.warp(raiseParams.publicSaleStart);

        vm.prank(controller);
        tokenAuth.deny(address(erc20));

        erc20.mint(alice, 0.01 ether);
        assertEq(erc20.balanceOf(alice), 0.01 ether);

        vm.startPrank(alice);
        erc20.approve(address(raises), 0.01 ether);

        vm.expectRevert(IRaises.InvalidCurrency.selector);
        raises.mint(1, 2, 0, 1);

        vm.stopPrank();
    }
}

contract TestSettlement is RaisesTest {
    function setUp() public override {
        super.setUp();
        projects.create(address(this));

        delete tierParams;
        tierParams.push(
            TierParams({
                tierType: TierType.Fan,
                supply: 100,
                price: 1 ether,
                limitPerAddress: 3,
                allowListRoot: MERKLE_ROOT
            })
        );

        raiseParams = RaiseParams({
            currency: ETH,
            goal: 1 ether,
            max: 2 ether,
            presaleStart: uint64(block.timestamp),
            presaleEnd: uint64(block.timestamp) + 10 days,
            publicSaleStart: uint64(block.timestamp) + 10 days,
            publicSaleEnd: uint64(block.timestamp) + 20 days
        });

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        deal(alice, 2 ether);
        vm.warp(raiseParams.publicSaleStart);
    }

    function test_settle_sets_state_to_funded_when_goal_is_met() public {
        vm.prank(alice);
        raises.mint{value: 1 ether}(1, 1, 0, 1);

        vm.warp(raiseParams.publicSaleEnd + 1);

        raises.settle(1, 1);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.state), uint8(RaiseState.Funded));
    }

    function test_funded_settle_emits_event() public {
        vm.prank(alice);
        raises.mint{value: 1 ether}(1, 1, 0, 1);

        vm.warp(raiseParams.publicSaleEnd + 1);

        vm.expectEmit(true, true, false, true);
        emit SettleRaise(1, 1, RaiseState.Funded);
        raises.settle(1, 1);
    }

    function test_settle_increases_global_fee_balance_when_goal_is_met() public {
        assertEq(raises.fees(ETH), 0);

        vm.prank(alice);
        raises.mint{value: 1 ether}(1, 1, 0, 1);

        vm.warp(raiseParams.publicSaleEnd + 1);

        raises.settle(1, 1);

        assertEq(raises.fees(ETH), 0.05 ether);
    }

    function test_settle_sets_state_to_cancelled_when_goal_is_not_met() public {
        vm.warp(raiseParams.publicSaleEnd + 1);

        raises.settle(1, 1);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.state), uint8(RaiseState.Cancelled));
    }

    function test_cancelled_settle_emits_event() public {
        vm.warp(raiseParams.publicSaleEnd + 1);

        vm.expectEmit(true, true, false, true);
        emit SettleRaise(1, 1, RaiseState.Cancelled);
        raises.settle(1, 1);
    }

    function test_settle_ongoing_raise_reverts_raise_not_ended() public {
        vm.expectRevert(IRaises.RaiseNotEnded.selector);
        raises.settle(1, 1);
    }

    function test_settle_invalid_project_reverts_not_found() public {
        vm.expectRevert(ICommonErrors.NotFound.selector);
        raises.settle(2, 1);
    }

    function test_settle_invalid_raise_reverts_not_found() public {
        vm.expectRevert(ICommonErrors.NotFound.selector);
        raises.settle(1, 2);
    }

    function test_settle_already_settled_reverts_raise_inactive() public {
        vm.prank(alice);
        raises.mint{value: 1 ether}(1, 1, 0, 1);

        vm.warp(raiseParams.publicSaleEnd + 1);
        raises.settle(1, 1);

        vm.expectRevert(IRaises.RaiseInactive.selector);
        raises.settle(1, 1);
    }
}

contract TestClose is RaisesTest {
    function setUp() public override {
        super.setUp();
        projects.create(address(this));

        delete tierParams;
        tierParams.push(
            TierParams({
                tierType: TierType.Fan,
                supply: 100,
                price: 1 ether,
                limitPerAddress: 3,
                allowListRoot: MERKLE_ROOT
            })
        );

        raiseParams = RaiseParams({
            currency: ETH,
            goal: 1 ether,
            max: 2 ether,
            presaleStart: uint64(block.timestamp),
            presaleEnd: uint64(block.timestamp) + 10 days,
            publicSaleStart: uint64(block.timestamp) + 10 days,
            publicSaleEnd: uint64(block.timestamp) + 20 days
        });

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        deal(alice, 2 ether);
        vm.warp(raiseParams.publicSaleStart);
    }

    function test_close_sets_state_to_funded_when_goal_is_met() public {
        vm.prank(alice);
        raises.mint{value: 1 ether}(1, 1, 0, 1);

        vm.prank(creators);
        raises.close(1, 1);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.state), uint8(RaiseState.Funded));
    }

    function test_close_emits_event() public {
        vm.prank(alice);
        raises.mint{value: 1 ether}(1, 1, 0, 1);

        vm.expectEmit(true, true, false, true);
        emit CloseRaise(1, 1, RaiseState.Funded);

        vm.prank(creators);
        raises.close(1, 1);
    }

    function test_close_reverts_when_goal_is_not_met() public {
        vm.expectRevert(IRaises.RaiseGoalNotMet.selector);
        vm.prank(creators);
        raises.close(1, 1);
    }

    function test_close_unauthorized_caller_reverts_forbidden() public {
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.close(1, 1);
    }

    function test_close_invalid_project_reverts_not_found() public {
        vm.expectRevert(ICommonErrors.NotFound.selector);
        vm.prank(creators);
        raises.close(2, 1);
    }

    function test_close_invalid_raise_reverts_not_found() public {
        vm.expectRevert(ICommonErrors.NotFound.selector);
        vm.prank(creators);
        raises.close(1, 2);
    }

    function test_close_already_closed_reverts_raise_inactive() public {
        vm.prank(alice);
        raises.mint{value: 1 ether}(1, 1, 0, 1);

        vm.prank(creators);
        raises.close(1, 1);

        vm.expectRevert(IRaises.RaiseInactive.selector);
        vm.prank(creators);
        raises.close(1, 1);
    }
}

contract TestCancellation is RaisesTest {
    function setUp() public override {
        super.setUp();
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);
    }

    function test_cancel_sets_state_to_cancelled() public {
        vm.prank(creators);
        raises.cancel(1, 1);

        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.state), uint8(RaiseState.Cancelled));
    }

    function test_cancel_emits_event() public {
        vm.expectEmit(true, true, false, true);
        emit CancelRaise(1, 1, RaiseState.Cancelled);

        vm.prank(creators);
        raises.cancel(1, 1);
    }

    function test_cancel_unauthorized_reverts_forbidden() public {
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.cancel(1, 1);
    }

    function test_cancel_invalid_project_reverts_not_found() public {
        vm.prank(creators);
        vm.expectRevert(ICommonErrors.NotFound.selector);
        raises.cancel(2, 1);
    }

    function test_cancel_invalid_raise_reverts_not_found() public {
        vm.prank(creators);
        vm.expectRevert(ICommonErrors.NotFound.selector);
        raises.cancel(1, 2);
    }

    function test_cancel_already_cancelled_reverts_raise_inactive() public {
        vm.prank(creators);
        raises.cancel(1, 1);

        vm.prank(creators);
        vm.expectRevert(IRaises.RaiseInactive.selector);
        raises.cancel(1, 1);
    }
}

contract TestRedemption is RaisesTest {
    function setUp() public override {
        super.setUp();
        projects.create(address(this));

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        deal(alice, 1 ether);
        vm.warp(raiseParams.publicSaleStart);
    }

    function test_settled_raise() public {
        // Alice mints a token in an active raise
        vm.prank(alice);
        uint256 tokenId = raises.mint{value: 0.1 ether}(1, 1, 1, 1);

        // Warp past raise end. This raise has not met its goal.
        vm.warp(raiseParams.publicSaleEnd + 1);

        // Settle the raise.
        raises.settle(1, 1);

        // The raise is now cancelled.
        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.state), uint8(RaiseState.Cancelled));

        // Alice still holds her token.
        assertEq(tokens.token(tokenId).balanceOf(alice, tokenId), 1);

        // Alice's ETH balance is 0.9
        assertEq(alice.balance, 0.9 ether);

        vm.startPrank(alice);
        tokens.token(tokenId).setApprovalForAll(address(raises), true);
        raises.redeem(1, 1, 1, 1);
        vm.stopPrank();

        // Alice has redeemed her token
        assertEq(tokens.token(tokenId).balanceOf(alice, tokenId), 0);

        // Alice's ETH balance is back to 1
        assertEq(alice.balance, 1 ether);
    }

    function test_redeem_emits_event() public {
        // Alice mints a token in an active raise
        vm.prank(alice);
        uint256 tokenId = raises.mint{value: 0.1 ether}(1, 1, 1, 1);

        // Warp past raise end. This raise has not met its goal.
        vm.warp(raiseParams.publicSaleEnd + 1);

        // Settle the raise.
        raises.settle(1, 1);

        vm.expectEmit(true, true, true, true);
        emit Redeem(1, 1, 1, alice, 1, ETH, 0.1 ether);

        // Alice redeems her token
        vm.startPrank(alice);
        tokens.token(tokenId).setApprovalForAll(address(raises), true);
        raises.redeem(1, 1, 1, 1);
        vm.stopPrank();
    }

    function test_redeem_active_raise_reverts_raise_active() public {
        vm.prank(alice);
        vm.expectRevert(IRaises.RaiseNotCancelled.selector);
        raises.redeem(1, 1, 1, 1);
    }

    function test_redeem_unowned_token_reverts() public {
        // Alice mints a token in an active raise
        vm.prank(alice);
        uint256 tokenId = raises.mint{value: 0.1 ether}(1, 1, 1, 1);

        // Warp past raise end. This raise has not met its goal.
        vm.warp(raiseParams.publicSaleEnd + 1);

        // Settle the raise.
        raises.settle(1, 1);

        // The raise is now cancelled.
        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.state), uint8(RaiseState.Cancelled));

        // Alice still holds her token.
        assertEq(tokens.token(tokenId).balanceOf(alice, tokenId), 1);

        vm.startPrank(bob);
        vm.expectRevert("ERC1155: caller is not token owner or approved");
        raises.redeem(1, 1, 1, 1);
    }

    function test_erc20_redeem() public {
        // Set up an ERC20 raise
        vm.warp(0);
        raiseParams.currency = address(erc20);

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);
        vm.warp(raiseParams.publicSaleStart);

        erc20.mint(alice, 1 ether);
        assertEq(erc20.balanceOf(alice), 1 ether);

        vm.prank(alice);
        erc20.approve(address(raises), 0.1 ether);

        // Alice mints a token in an active raise
        vm.prank(alice);
        uint256 tokenId = raises.mint(1, 2, 1, 1);

        // Warp past raise end. This raise has not met its goal.
        vm.warp(raiseParams.publicSaleEnd + 1);

        // Settle the raise.
        raises.settle(1, 2);

        // The raise is now cancelled.
        Raise memory raise = raises.getRaise(1, 2);
        assertEq(uint8(raise.state), uint8(RaiseState.Cancelled));

        // Alice still holds her token.
        assertEq(tokens.token(tokenId).balanceOf(alice, tokenId), 1);

        // Alice's ETH balance is 1
        assertEq(alice.balance, 1 ether);

        // Alice's ERC20 balance is 0.9
        assertEq(erc20.balanceOf(alice), 0.9 ether);

        vm.startPrank(alice);
        tokens.token(tokenId).setApprovalForAll(address(raises), true);
        raises.redeem(1, 2, 1, 1);
        vm.stopPrank();

        // Alice has redeemed her token
        assertEq(tokens.token(tokenId).balanceOf(alice, tokenId), 0);

        // Alice's ETH balance is still 1
        assertEq(alice.balance, 1 ether);

        // Alice's Token balance is back to 1
        assertEq(erc20.balanceOf(alice), 1 ether);
    }
}

contract TestWithdrawal is RaisesTest {
    function setUp() public override {
        super.setUp();
        projects.create(address(this));

        raiseParams.goal = 1 ether;

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        deal(alice, 1 ether);
        vm.warp(raiseParams.publicSaleStart);
    }

    function test_withdraw_active_raise_reverts_raise_active() public {
        vm.prank(creators);
        vm.expectRevert(IRaises.RaiseNotFunded.selector);
        raises.withdraw(1, 1, bob);
    }

    function test_withdraw_unauthorized_reverts_forbidden() public {
        vm.prank(alice);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.withdraw(1, 1, bob);
    }

    function test_withdraw_settled_raise() public {
        // Alice mints a token in an active raise
        vm.prank(alice);
        raises.mint{value: 1 ether}(1, 1, 2, 1);

        // Warp past raise end. This raise has met its goal.
        vm.warp(raiseParams.publicSaleEnd + 1);

        // Settle the raise.
        raises.settle(1, 1);

        // The raise is now funded.
        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.state), uint8(RaiseState.Funded));

        // Contract ETH balance is 1
        assertEq(address(raises).balance, 1 ether);

        // Emits event
        vm.expectEmit(true, true, true, true);
        emit WithdrawRaiseFunds(1, 1, bob, ETH, 0.95 ether);

        vm.prank(creators);
        raises.withdraw(1, 1, bob);

        // Contract holds 5% of raise from protocol fees
        assertEq(address(raises).balance, 0.05 ether);

        // Bob's ETH balance is the remaining 95%
        assertEq(address(bob).balance, 0.95 ether);
    }

    function test_withdraw_erc20_settled_raise() public {
        // Set up an ERC20 raise
        vm.warp(0);
        raiseParams.goal = 0.1 ether;
        raiseParams.currency = address(erc20);

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);
        vm.warp(raiseParams.publicSaleStart);

        erc20.mint(alice, 1 ether);
        assertEq(erc20.balanceOf(alice), 1 ether);

        vm.prank(alice);
        erc20.approve(address(raises), 0.1 ether);

        // Alice mints a token in an active raise
        vm.prank(alice);
        raises.mint(1, 2, 1, 1);

        // Warp past raise end. This raise has met its goal.
        vm.warp(raiseParams.publicSaleEnd + 1);

        // Settle the raise.
        raises.settle(1, 2);

        // The raise is now funded.
        Raise memory raise = raises.getRaise(1, 2);
        assertEq(uint8(raise.state), uint8(RaiseState.Funded));

        // Alice's ERC20 balance is 0.9
        assertEq(erc20.balanceOf(alice), 0.9 ether);

        // Contract's ERC20 balance is 0.1
        assertEq(erc20.balanceOf(address(raises)), 0.1 ether);

        // Emits event
        vm.expectEmit(true, true, true, true);
        emit WithdrawRaiseFunds(1, 2, bob, address(erc20), 0.095 ether);

        // Withdraw balance to Bob
        vm.prank(creators);
        raises.withdraw(1, 2, bob);

        // Contract's ERC20 balance is now 0.005
        // (5% of the raise is retained in fees)
        assertEq(erc20.balanceOf(address(raises)), 0.005 ether);

        // Bob's ERC20 balance is now 0.095
        // (95% of the raise withdrawn to creator)
        assertEq(erc20.balanceOf(bob), 0.095 ether);
    }
}

contract TestFees is RaisesTest {
    function setUp() public override {
        super.setUp();
        projects.create(address(this));

        raiseParams.goal = 1 ether;

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);

        deal(alice, 1 ether);
        vm.warp(raiseParams.publicSaleStart);
    }

    function test_withdraw_fees_unauthorized_reverts_forbidden() public {
        vm.prank(alice);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.withdrawFees(ETH, alice);
    }

    function test_withdraw_fees_no_fees_reverts_zero_balance() public {
        vm.prank(controller);
        vm.expectRevert(IRaises.ZeroBalance.selector);
        raises.withdrawFees(ETH, protocol);
    }

    function test_withdraw_eth_fees_settled_raise() public {
        // Alice mints a token in an active raise
        vm.prank(alice);
        raises.mint{value: 1 ether}(1, 1, 2, 1);

        // Warp past raise end. This raise has met its goal.
        vm.warp(raiseParams.publicSaleEnd + 1);

        // Settle the raise.
        raises.settle(1, 1);

        // The raise is now funded.
        Raise memory raise = raises.getRaise(1, 1);
        assertEq(uint8(raise.state), uint8(RaiseState.Funded));

        // Contract ETH balance is 1
        assertEq(address(raises).balance, 1 ether);

        // Protocol fee balance is 0.05 ETH
        assertEq(raises.fees(ETH), 0.05 ether);

        // Emits event
        vm.expectEmit(true, false, false, true);
        emit WithdrawFees(protocol, ETH, 0.05 ether);

        vm.prank(controller);
        raises.withdrawFees(ETH, protocol);

        // Protocol ETH balance is 0.05 ETH
        assertEq(address(protocol).balance, 0.05 ether);
    }

    function test_withdraw_erc20_fees_settled_raise() public {
        // Set up an ERC20 raise
        vm.warp(0);
        raiseParams.goal = 0.1 ether;
        raiseParams.currency = address(erc20);

        vm.prank(creators);
        raises.create(1, raiseParams, tierParams);
        vm.warp(raiseParams.publicSaleStart);

        erc20.mint(alice, 1 ether);
        assertEq(erc20.balanceOf(alice), 1 ether);

        vm.prank(alice);
        erc20.approve(address(raises), 0.1 ether);

        // Alice mints a token in an active raise
        vm.prank(alice);
        raises.mint(1, 2, 1, 1);

        // Warp past raise end. This raise has met its goal.
        vm.warp(raiseParams.publicSaleEnd + 1);

        // Settle the raise.
        raises.settle(1, 2);

        // The raise is now funded.
        Raise memory raise = raises.getRaise(1, 2);
        assertEq(uint8(raise.state), uint8(RaiseState.Funded));

        // Alice's ERC20 balance is 0.9
        assertEq(erc20.balanceOf(alice), 0.9 ether);

        // Contract's ERC20 balance is 0.1
        assertEq(erc20.balanceOf(address(raises)), 0.1 ether);

        // Emits event
        vm.expectEmit(true, false, false, true);
        emit WithdrawFees(protocol, address(erc20), 0.005 ether);

        // Withdraw fee balance to protocol wallet
        vm.prank(controller);
        raises.withdrawFees(address(erc20), protocol);

        // Contract's ERC20 balance is now 0.095
        assertEq(erc20.balanceOf(address(raises)), 0.095 ether);

        // Protocol ERC20 balance is 0.005
        assertEq(erc20.balanceOf(address(protocol)), 0.005 ether);
    }
}

contract TestPause is RaisesTest {
    function test_is_not_paused_by_default() public {
        assertEq(raises.paused(), false);
    }

    function test_can_be_paused_by_controller() public {
        vm.prank(controller);
        raises.pause();

        assertEq(raises.paused(), true);
    }

    function test_cannot_be_paused_by_non_controller() public {
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.pause();

        assertEq(raises.paused(), false);
    }

    function test_can_be_unpaused_by_controller() public {
        vm.prank(controller);
        raises.pause();

        assertEq(raises.paused(), true);

        vm.prank(controller);
        raises.unpause();

        assertEq(raises.paused(), false);
    }

    function test_cannot_be_unpaused_by_non_controller() public {
        vm.prank(controller);
        raises.pause();

        assertEq(raises.paused(), true);

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.unpause();

        assertEq(raises.paused(), true);
    }

    function test_cannot_create_raise_when_paused() public {
        projects.create(address(this));

        vm.prank(controller);
        raises.pause();

        vm.prank(creators);
        vm.expectRevert("Pausable: paused");
        raises.create(1, raiseParams, tierParams);
    }

    function test_cannot_mint_when_paused() public {
        vm.prank(controller);
        raises.pause();

        vm.expectRevert("Pausable: paused");
        raises.mint(1, 1, 1, 1);
    }

    function test_cannot_mint_with_proof_when_paused() public {
        vm.prank(controller);
        raises.pause();

        vm.expectRevert("Pausable: paused");
        raises.mint(1, 1, 1, 1, new bytes32[](0));
    }

    function test_cannot_settle_when_paused() public {
        vm.prank(controller);
        raises.pause();

        vm.expectRevert("Pausable: paused");
        raises.settle(1, 1);
    }

    function test_cannot_cancel_when_paused() public {
        vm.prank(controller);
        raises.pause();

        vm.prank(creators);
        vm.expectRevert("Pausable: paused");
        raises.cancel(1, 1);
    }

    function test_cannot_close_when_paused() public {
        vm.prank(controller);
        raises.pause();

        vm.prank(creators);
        vm.expectRevert("Pausable: paused");
        raises.close(1, 1);
    }

    function test_cannot_withdraw_when_paused() public {
        vm.prank(controller);
        raises.pause();

        vm.prank(creators);
        vm.expectRevert("Pausable: paused");
        raises.withdraw(1, 1, alice);
    }

    function test_cannot_redeem_when_paused() public {
        vm.prank(controller);
        raises.pause();

        vm.expectRevert("Pausable: paused");
        raises.redeem(1, 1, 1, 1);
    }
}

contract TestController is RaisesTest {
    function test_has_controller_address() public {
        assertEq(raises.controller(), controller);
    }

    function test_controller_can_set_creators() public {
        address newCreators = mkaddr("new creators");

        vm.prank(controller);
        raises.setDependency("creators", newCreators);

        assertEq(raises.creators(), newCreators);
    }

    function test_non_controller_cannot_set_creators() public {
        address newCreators = mkaddr("new creators");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.setDependency("creators", newCreators);
    }

    function test_controller_can_set_projects() public {
        address newProjects = mkaddr("new projects");

        vm.prank(controller);
        raises.setDependency("projects", newProjects);

        assertEq(raises.projects(), newProjects);
    }

    function test_non_controller_cannot_set_projects() public {
        address newProjects = mkaddr("new projects");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.setDependency("projects", newProjects);
    }

    function test_controller_can_set_minter() public {
        address newMinter = mkaddr("new minter");

        vm.prank(controller);
        raises.setDependency("minter", newMinter);

        assertEq(raises.minter(), newMinter);
    }

    function test_non_controller_cannot_set_minter() public {
        address newMinter = mkaddr("new minter");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.setDependency("minter", newMinter);
    }

    function test_controller_can_set_tokens() public {
        address newTokens = mkaddr("new tokens");

        vm.prank(controller);
        raises.setDependency("tokens", newTokens);

        assertEq(raises.tokens(), newTokens);
    }

    function test_non_controller_cannot_set_tokens() public {
        address newTokens = mkaddr("new tokens");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.setDependency("tokens", newTokens);
    }

    function test_controller_can_set_tokenAuth() public {
        address newTokenAuth = mkaddr("new tokenAuth");

        vm.prank(controller);
        raises.setDependency("tokenAuth", newTokenAuth);

        assertEq(raises.tokenAuth(), newTokenAuth);
    }

    function test_non_controller_cannot_set_tokenAuth() public {
        address newTokenAuth = mkaddr("new tokenAuth");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        raises.setDependency("tokenAuth", newTokenAuth);
    }
}

contract TestContractInfo is RaisesTest {
    function test_has_name() public {
        assertEq(raises.NAME(), "Raises");
    }

    function test_has_version() public {
        assertEq(raises.VERSION(), "0.0.1");
    }
}
