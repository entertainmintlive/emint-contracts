// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {IOwnable2Step} from "../../src/interfaces/IOwnable2Step.sol";
import {EmintV1Fab} from "../fabs/EmintV1Fab.sol";
import {Contracts, Create2} from "../helpers/Create2.sol";

contract DeployEmintV1 is Script {
    event Deployment(Contracts contracts);

    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function run() public {
        string memory tokenURI = "https://www.staging-entertainmint.com/api/metadata/tokens/";
        string memory contractURI = "https://www.staging-entertainmint.com/api/metadata/contracts/";
        address royaltyReceiver = msg.sender;
        address owner = msg.sender;
        address collectionOwner = msg.sender;

        vm.startBroadcast();
        new EmintV1Fab{ salt: "emint-v1-fab" }(tokenURI, contractURI, royaltyReceiver, owner, collectionOwner);
        Contracts memory contracts =
            Create2.contracts(CREATE2_DEPLOYER, tokenURI, contractURI, royaltyReceiver, owner, collectionOwner);
        IOwnable2Step(contracts.controller).acceptOwnership();
        vm.stopBroadcast();

        emit Deployment(contracts);
    }
}
