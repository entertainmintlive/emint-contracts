// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

import "./EmintTest.t.sol";
import "../src/interfaces/ITokens.sol";
import "../src/interfaces/ICommonErrors.sol";
import "../src/Tokens.sol";
import "../src/Metadata.sol";
import "../src/Royalties.sol";

import {TokenCodec} from "../src/libraries/codecs/TokenCodec.sol";
import {RaiseCodec} from "../src/libraries/codecs/RaiseCodec.sol";
import {TokenData, TokenType} from "../src/structs/TokenData.sol";
import {RaiseData, TierType} from "../src/structs/RaiseData.sol";

contract TokensTest is EmintTest, ERC1155Holder {
    Metadata internal metadata;
    Tokens internal tokens;
    Royalties internal royalties;

    address eve = mkaddr("eve");
    address protocol = mkaddr("protocol");

    address controller = mkaddr("controller");
    address minter = mkaddr("minter");
    address deployer = mkaddr("deployer");
    address creators = mkaddr("creators");
    address owner = mkaddr("owner");

    event SetMinter(address oldMinter, address newMinter);
    event SetDeployer(address oldDeployer, address newDeployer);
    event SetMetadata(address oldMetadata, address newMetadata);
    event SetRoyalties(address oldRoyalties, address newRoyalties);
    event UpdateTokenImplementation(address oldImpl, address newImpl);

    string constant DEFAULT_TOKEN_URI = "http://default-uri.com/";
    string constant DEFAULT_CONTRACT_URI = "http://default-uri.com/contract/";

    function setUp() public {
        metadata = new Metadata(controller, DEFAULT_TOKEN_URI, DEFAULT_CONTRACT_URI, owner);

        vm.prank(controller);
        metadata.setDependency("creators", creators);

        royalties = new Royalties(controller, protocol);
        tokens = new Tokens(controller);

        vm.startPrank(controller);
        tokens.setDependency("minter", minter);
        tokens.setDependency("deployer", deployer);
        tokens.setDependency("metadata", address(metadata));
        tokens.setDependency("royalties", address(royalties));
        vm.stopPrank();
    }
}

contract TestDeploy is TokensTest {
    function test_has_deployer_address() public {
        assertEq(tokens.deployer(), deployer);
    }

    function test_deployer_can_deploy_token() public {
        vm.startPrank(deployer);
        address token = tokens.deploy();
        tokens.register(1, token);
        vm.stopPrank();

        assertEq(address(tokens.token(1)), token);
    }

    function test_non_deployer_cannot_deploy_token() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokens.deploy();
    }

    function test_non_deployer_cannot_register_token() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokens.register(1, address(0));
    }
}

contract TestMint is TokensTest {
    function test_has_minter_address() public {
        assertEq(tokens.minter(), minter);
    }

    function test_minter_can_mint_one() public {
        vm.startPrank(deployer);
        address token = tokens.deploy();
        tokens.register(1, token);
        vm.stopPrank();

        vm.startPrank(minter);
        tokens.mint(address(this), 1, 1, "");
        vm.stopPrank();

        assertEq(tokens.token(1).balanceOf(address(this), 1), 1);
    }

    function test_non_minter_cannot_mint_one() public {
        vm.prank(eve);
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokens.mint(address(this), 1, 1, "");
    }
}

contract TestMetadata is TokensTest {
    function test_has_metadata_address() public {
        assertEq(tokens.metadata(), address(metadata));
    }
}

contract TestRoyalties is TokensTest {
    function test_has_royalties_address() public {
        assertEq(tokens.royalties(), address(royalties));
    }
}

contract TestController is TokensTest {
    function test_has_controller_address() public {
        assertEq(tokens.controller(), controller);
    }

    function test_controller_address_zero_check() public {
        vm.expectRevert(ICommonErrors.ZeroAddress.selector);
        new Tokens(address(0));
    }

    function test_controller_can_set_minter() public {
        address newMinter = mkaddr("new minter");

        vm.prank(controller);
        tokens.setDependency("minter", newMinter);

        assertEq(tokens.minter(), newMinter);
    }

    function test_non_controller_cannot_set_minter() public {
        address newMinter = mkaddr("new minter");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokens.setDependency("minter", newMinter);
    }

    function test_set_minter_emits_event() public {
        address newMinter = mkaddr("new minter");

        vm.expectEmit(false, false, false, true);
        emit SetMinter(minter, newMinter);

        vm.prank(controller);
        tokens.setDependency("minter", newMinter);

        assertEq(tokens.minter(), newMinter);
    }

    function test_controller_can_set_metadata() public {
        address newMetadata = mkaddr("new metadata");

        vm.prank(controller);
        tokens.setDependency("metadata", newMetadata);

        assertEq(tokens.metadata(), newMetadata);
    }

    function test_non_controller_cannot_set_metadata() public {
        address newMetadata = mkaddr("new metadata");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokens.setDependency("metadata", newMetadata);
    }

    function test_set_metadata_emits_event() public {
        address newMetadata = mkaddr("new metadata");

        vm.expectEmit(false, false, false, true);
        emit SetMetadata(address(metadata), newMetadata);

        vm.prank(controller);
        tokens.setDependency("metadata", newMetadata);

        assertEq(tokens.metadata(), newMetadata);
    }

    function test_controller_can_set_royalties() public {
        address newRoyalties = mkaddr("new royalties");

        vm.prank(controller);
        tokens.setDependency("royalties", newRoyalties);

        assertEq(tokens.royalties(), newRoyalties);
    }

    function test_non_controller_cannot_set_royalties() public {
        address newRoyalties = mkaddr("new royalties");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokens.setDependency("royalties", newRoyalties);
    }

    function test_set_royalties_emits_event() public {
        address newRoyalties = mkaddr("new royalties");

        vm.expectEmit(false, false, false, true);
        emit SetRoyalties(address(royalties), newRoyalties);

        vm.prank(controller);
        tokens.setDependency("royalties", newRoyalties);

        assertEq(tokens.royalties(), newRoyalties);
    }

    function test_controller_can_set_deployer() public {
        address newDeployer = mkaddr("new deployer");

        vm.prank(controller);
        tokens.setDependency("deployer", newDeployer);

        assertEq(tokens.deployer(), newDeployer);
    }

    function test_non_controller_cannot_set_deployer() public {
        address newDeployer = mkaddr("new deployer");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokens.setDependency("deployer", newDeployer);
    }

    function test_set_deployer_emits_event() public {
        address newDeployer = mkaddr("new deployer");

        vm.expectEmit(false, false, false, true);
        emit SetDeployer(address(deployer), newDeployer);

        vm.prank(controller);
        tokens.setDependency("deployer", newDeployer);

        assertEq(tokens.deployer(), newDeployer);
    }

    function test_controller_cannot_set_invalid_dependency() public {
        address invalid = mkaddr("invalid");

        vm.expectRevert(abi.encodeWithSelector(IControllable.InvalidDependency.selector, bytes32("invalid")));
        vm.prank(controller);
        tokens.setDependency("invalid", invalid);
    }

    function test_controller_cannot_set_zero_address() public {
        vm.expectRevert(ICommonErrors.ZeroAddress.selector);
        vm.prank(controller);
        tokens.setDependency("royalties", address(0));
    }

    function test_controller_can_update_token_implementation() public {
        address newTokenImpl = mkaddr("new token implementation");

        vm.prank(controller);
        tokens.updateTokenImplementation(newTokenImpl);

        assertEq(tokens.emint1155(), newTokenImpl);
    }

    function test_non_controller_cannot_update_token_implementation() public {
        address newTokenImpl = mkaddr("new token implementation");

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokens.updateTokenImplementation(newTokenImpl);
    }

    function test_update_token_implementation_emits_event() public {
        address newTokenImpl = mkaddr("new token implementation");

        vm.expectEmit(false, false, false, true);
        emit UpdateTokenImplementation(tokens.emint1155(), newTokenImpl);

        vm.prank(controller);
        tokens.updateTokenImplementation(newTokenImpl);

        assertEq(tokens.emint1155(), newTokenImpl);
    }
}

contract TestPause is TokensTest {
    function test_is_not_paused_by_default() public {
        assertEq(tokens.paused(), false);
    }

    function test_can_be_paused_by_controller() public {
        vm.prank(controller);
        tokens.pause();

        assertEq(tokens.paused(), true);
    }

    function test_cannot_be_paused_by_non_controller() public {
        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokens.pause();

        assertEq(tokens.paused(), false);
    }

    function test_can_be_unpaused_by_controller() public {
        vm.prank(controller);
        tokens.pause();

        assertEq(tokens.paused(), true);

        vm.prank(controller);
        tokens.unpause();

        assertEq(tokens.paused(), false);
    }

    function test_cannot_be_unpaused_by_non_controller() public {
        vm.prank(controller);
        tokens.pause();

        assertEq(tokens.paused(), true);

        vm.expectRevert(ICommonErrors.Forbidden.selector);
        tokens.unpause();

        assertEq(tokens.paused(), true);
    }

    function test_cannot_mint_when_paused() public {
        vm.prank(controller);
        tokens.pause();

        vm.prank(minter);
        vm.expectRevert("Pausable: paused");
        tokens.mint(address(this), 1, 1, "");
    }
}

contract TestContractInfo is TokensTest {
    function test_has_name() public {
        assertEq(tokens.NAME(), "Tokens");
    }

    function test_has_version() public {
        assertEq(tokens.VERSION(), "0.0.1");
    }
}
