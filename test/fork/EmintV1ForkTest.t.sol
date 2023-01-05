// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../EmintTest.t.sol";
import "../../script/fabs/EmintV1Fab.sol";
import "../../script/helpers/Create2.sol";

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

abstract contract EmintV1ForkTest is EmintTest {
    uint256 internal forkBlock;
    Contracts internal contracts;
    Controller internal controller;
    Creators internal creators;
    Raises internal raises;
    Tokens internal tokens;

    string internal contractURI = "https://staging-entertainmint.com/api/metadata/contracts/";
    string internal tokenURI = "https://staging-entertainmint.com/api/metadata/tokens/";

    address internal royaltyReceiver = mkaddr("royalty receiver");
    address internal owner = mkaddr("owner");
    address internal collectionOwner = mkaddr("collection owner");

    address internal alice = mkaddr("alice");
    address internal bob = mkaddr("bob");
    address internal carol = mkaddr("carol");
    address internal dave = mkaddr("dave");

    address internal pepsi = mkaddr("pepsi");
    address internal disney = mkaddr("disney");

    constructor(uint256 _forkBlock) {
        forkBlock = _forkBlock;
    }

    function setUp() public virtual {
        if (forkBlock != 0) {
          vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);
        } else {
          vm.createSelectFork(vm.rpcUrl("mainnet"));
        }

        new EmintV1Fab{ salt: "emint-v1-fab" }(tokenURI, contractURI, royaltyReceiver, owner, collectionOwner);
        contracts = Create2.contracts(address(this), tokenURI, contractURI, royaltyReceiver, owner, collectionOwner);
        controller = Controller(contracts.controller);
        creators = Creators(contracts.creators);
        raises = Raises(contracts.raises);
        tokens = Tokens(contracts.tokens);

        deal(bob, 10 ether);
        deal(carol, 10 ether);
        deal(dave, 10 ether);
        deal(pepsi, 10 ether);
        deal(disney, 10 ether);
    }
}
