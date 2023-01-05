// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {Contracts, Create2} from "../helpers/Create2.sol";
import {Controller} from "../../src/Controller.sol";
import {TokenAuth} from "../../src/TokenAuth.sol";
import {CreatorAuth} from "../../src/CreatorAuth.sol";
import {Projects} from "../../src/Projects.sol";
import {Creators} from "../../src/Creators.sol";
import "../../src/Raises.sol";
import {Metadata} from "../../src/Metadata.sol";
import {Royalties} from "../../src/Royalties.sol";
import {Minter} from "../../src/Minter.sol";
import {TokenDeployer} from "../../src/TokenDeployer.sol";
import {Tokens} from "../../src/Tokens.sol";

contract SetupRaise is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function run() public {
        string memory tokenURI = "https://www.staging-entertainmint.com/api/metadata/tokens/";
        string memory contractURI = "https://www.staging-entertainmint.com/api/metadata/contracts/";
        address royaltyReceiver = 0x3B4642507B1e9B4bC5ebfe75a97826A1c59D94c0;
        address owner = 0x3B4642507B1e9B4bC5ebfe75a97826A1c59D94c0;
        address collectionOwner = 0x3B4642507B1e9B4bC5ebfe75a97826A1c59D94c0;
        Contracts memory contracts =
            Create2.contracts(CREATE2_DEPLOYER, tokenURI, contractURI, royaltyReceiver, owner, collectionOwner);

        RaiseParams memory raiseParams = RaiseParams({
            currency: ETH,
            goal: 0.05 ether,
            max: 2.5 ether,
            presaleStart: uint64(block.timestamp) + 60,
            presaleEnd: uint64(block.timestamp) + 60,
            publicSaleStart: uint64(block.timestamp) + 60,
            publicSaleEnd: uint64(block.timestamp) + 20 days
        });
        TierParams[] memory tierParams = new TierParams[](5);
        tierParams[0] =
            TierParams({tierType: TierType.Fan, supply: 100, price: 0.002 ether, limitPerAddress: 5, allowListRoot: ""});
        tierParams[1] =
            TierParams({tierType: TierType.Fan, supply: 30, price: 0.01 ether, limitPerAddress: 3, allowListRoot: ""});
        tierParams[2] =
            TierParams({tierType: TierType.Fan, supply: 10, price: 0.05 ether, limitPerAddress: 1, allowListRoot: ""});
        tierParams[3] =
            TierParams({tierType: TierType.Brand, supply: 1, price: 0.5 ether, limitPerAddress: 1, allowListRoot: ""});
        tierParams[4] =
            TierParams({tierType: TierType.Brand, supply: 1, price: 0.1 ether, limitPerAddress: 1, allowListRoot: ""});

        Creators creators = Creators(contracts.creators);

        vm.startBroadcast();
        uint32 projectId = creators.createProject();
        creators.createRaise(projectId, raiseParams, tierParams);
        vm.stopBroadcast();
    }
}
