// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

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

contract EmintV1Fab {
    event Deployed(bytes32 name, address contractAddress);

    constructor(
        string memory tokenBaseURI,
        string memory contractBaseURI,
        address royaltyReceiver,
        address owner,
        address collectionOwner
    ) {
        // Deploy contracts to deterministic addresses using CREATE2
        Controller controller = new Controller{ salt: "controller" }();

        TokenAuth tokenAuth = new TokenAuth{ salt: "tokenAuth" }(address(controller));
        CreatorAuth creatorAuth = new CreatorAuth{ salt: "creatorAuth" }(address(controller));

        Projects projects = new Projects{ salt: "projects" }(address(controller));
        Creators creators = new Creators{ salt: "creators" }(address(controller));
        Raises raises = new Raises{ salt: "raises" }(address(controller));

        Metadata metadata = new Metadata{ salt: "metadata" }(
            address(controller),
            tokenBaseURI,
            contractBaseURI,
            collectionOwner
        );
        Royalties royalties = new Royalties{ salt: "royalties" }(address(controller), royaltyReceiver);
        Minter minter = new Minter{ salt: "minter" }(address(controller));
        TokenDeployer deployer = new TokenDeployer{ salt: "tokenDeployer" }(address(controller));
        Tokens tokens = new Tokens{ salt: "tokens" }(address(controller));

        // Set up contract dependencies
        controller.setDependency(address(tokens), "minter", address(minter));
        controller.setDependency(address(tokens), "deployer", address(deployer));
        controller.setDependency(address(tokens), "metadata", address(metadata));
        controller.setDependency(address(tokens), "royalties", address(royalties));

        controller.setDependency(address(minter), "tokens", address(tokens));
        controller.setDependency(address(deployer), "tokens", address(tokens));

        controller.setDependency(address(raises), "creators", address(creators));
        controller.setDependency(address(raises), "projects", address(projects));
        controller.setDependency(address(raises), "minter", address(minter));
        controller.setDependency(address(raises), "deployer", address(deployer));
        controller.setDependency(address(raises), "tokens", address(tokens));
        controller.setDependency(address(raises), "tokenAuth", address(tokenAuth));

        controller.setDependency(address(creators), "creatorAuth", address(creatorAuth));
        controller.setDependency(address(creators), "metadata", address(metadata));
        controller.setDependency(address(creators), "projects", address(projects));
        controller.setDependency(address(creators), "raises", address(raises));

        // Allow creators to call projects
        controller.allow(address(projects), address(creators));

        // Allow raises to call minter and deployer
        controller.allow(address(minter), address(raises));
        controller.allow(address(deployer), address(raises));

        // Transfer ownership to specified owner address
        controller.transferOwnership(owner);

        // Emit deployment addresses
        emit Deployed("controller", address(controller));
        emit Deployed("tokenAuth", address(tokenAuth));
        emit Deployed("creatorAuth", address(creatorAuth));
        emit Deployed("projects", address(projects));
        emit Deployed("creators", address(creators));
        emit Deployed("raises", address(raises));
        emit Deployed("metadata", address(metadata));
        emit Deployed("royalties", address(royalties));
        emit Deployed("minter", address(minter));
        emit Deployed("dpeloyer", address(deployer));
        emit Deployed("tokens", address(tokens));

        // Destroy fab contract
        selfdestruct(payable(owner));
    }
}
