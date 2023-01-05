// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {EmintV1Fab} from "../../script/fabs/EmintV1Fab.sol";
import {Controller} from "../../src/Controller.sol";
import {TokenAuth} from "../../src/TokenAuth.sol";
import {CreatorAuth} from "../../src/CreatorAuth.sol";
import {Projects} from "../../src/Projects.sol";
import {Creators} from "../../src/Creators.sol";
import {Raises} from "../../src/Raises.sol";
import {Metadata} from "../../src/Metadata.sol";
import {Royalties} from "../../src/Royalties.sol";
import {Minter} from "../../src/Minter.sol";
import {TokenDeployer} from "../../src/TokenDeployer.sol";
import {Tokens} from "../../src/Tokens.sol";

address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

struct Contracts {
    address fab;
    address controller;
    address tokenAuth;
    address creatorAuth;
    address projects;
    address creators;
    address raises;
    address metadata;
    address royalties;
    address minter;
    address deployer;
    address tokens;
}

library Create2 {
    function contracts(
        address deployer,
        string memory tokenURI,
        string memory contractURI,
        address royaltyReceiver,
        address owner,
        address collectionOwner
    ) internal pure returns (Contracts memory) {
        address fab = create2Addr(
            deployer,
            "emint-v1-fab",
            abi.encodePacked(
                type(EmintV1Fab).creationCode,
                abi.encode(tokenURI, contractURI, royaltyReceiver, owner, collectionOwner)
            )
        );
        address controller = create2Addr(fab, "controller", type(Controller).creationCode);

        return Contracts({
            fab: fab,
            controller: controller,
            tokenAuth: create2Addr(fab, "tokenAuth", abi.encodePacked(type(TokenAuth).creationCode, abi.encode(controller))),
            creatorAuth: create2Addr(
                fab, "creatorAuth", abi.encodePacked(type(CreatorAuth).creationCode, abi.encode(controller))
                ),
            projects: create2Addr(fab, "projects", abi.encodePacked(type(Projects).creationCode, abi.encode(controller))),
            creators: create2Addr(fab, "creators", abi.encodePacked(type(Creators).creationCode, abi.encode(controller))),
            raises: create2Addr(fab, "raises", abi.encodePacked(type(Raises).creationCode, abi.encode(controller))),
            metadata: create2Addr(
                fab,
                "metadata",
                abi.encodePacked(
                    type(Metadata).creationCode, abi.encode(controller, tokenURI, contractURI, collectionOwner)
                )
                ),
            royalties: create2Addr(
                fab, "royalties", abi.encodePacked(type(Royalties).creationCode, abi.encode(controller, royaltyReceiver))
                ),
            minter: create2Addr(fab, "minter", abi.encodePacked(type(Minter).creationCode, abi.encode(controller))),
            deployer: create2Addr(
                fab, "deployer", abi.encodePacked(type(TokenDeployer).creationCode, abi.encode(controller))
                ),
            tokens: create2Addr(fab, "tokens", abi.encodePacked(type(Tokens).creationCode, abi.encode(controller)))
        });
    }

    function create2Addr(address deployer, bytes32 salt, bytes memory initCode) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(initCode))))));
    }
}
