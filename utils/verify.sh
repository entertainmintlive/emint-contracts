#!/usr/bin/env bash

CONTROLLER_ADDR=0x000000000000000000000000BA89b33a8D7836c2FBFd6aca0971C382fa93E385
forge verify-contract --chain 5 0xBA89b33a8D7836c2FBFd6aca0971C382fa93E385 src/Controller.sol:Controller $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x909683B991c51081E17FE5A8917dF02a9C2d4f57 src/TokenAuth.sol:TokenAuth --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0xC8171fC399C541Fffd675F7df666fCbd870728BB src/CreatorAuth.sol:CreatorAuth --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x7def8273a99168cAcbac04fB2D77138e8c61156d src/Projects.sol:Projects --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x1c6c6D6bFD14f000B3Dc264630b0cc4B570CeDa1 src/Creators.sol:Creators --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x142D48AE833e4f346CBB340E812f3EB6d32747e2 src/Raises.sol:Raises --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0xD453B55f548e4eb900073fd34435e97411C5a381 src/Metadata.sol:Metadata --constructor-args 0x000000000000000000000000BA89b33a8D7836c2FBFd6aca0971C382fa93E385000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000003b4642507b1e9b4bc5ebfe75a97826a1c59d94c0000000000000000000000000000000000000000000000000000000000000003a68747470733a2f2f7777772e73746167696e672d656e7465727461696e6d696e742e636f6d2f6170692f6d657461646174612f746f6b656e732f000000000000000000000000000000000000000000000000000000000000000000000000003d68747470733a2f2f7777772e73746167696e672d656e7465727461696e6d696e742e636f6d2f6170692f6d657461646174612f636f6e7472616374732f000000 $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x75d837c62800887A2bfa9a2D481F67DF45332DfF src/Royalties.sol:Royalties --constructor-args 0x000000000000000000000000BA89b33a8D7836c2FBFd6aca0971C382fa93E3850000000000000000000000003b4642507b1e9b4bc5ebfe75a97826a1c59d94c0 $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x88846F296E13EC43d8B5FB89f19812ce5eb5a038 src/Minter.sol:Minter --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x3C753E1B9623F2E082D39F7dae629c0F91593F7C src/TokenDeployer.sol:TokenDeployer --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0xCD071ef36cc13430FCa2c231D18Eb91cff601cc0 src/Tokens.sol:Tokens --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0xc0b78B2179B15756e91C4611E71eE92298a32436 src/tokens/Emint1155.sol:Emint1155 $ETHERSCAN_API_KEY
