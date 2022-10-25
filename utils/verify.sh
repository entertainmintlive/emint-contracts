#!/usr/bin/env bash

CONTROLLER_ADDR=0x00000000000000000000000097e89840d02dd999a1ac089fbcf9f8399e8653d4
forge verify-contract --chain 5 0x97e89840D02DD999A1AC089fbcF9f8399E8653d4 src/Controller.sol:Controller $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x4Bc9Ed4BEC2df6DeBCE8d502c09F28161c5B7dA1 src/TokenAuth.sol:TokenAuth --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0xF67C749e7D817df408b5a89c3c05114146cD74FF src/CreatorAuth.sol:CreatorAuth --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x65c5cA50A2A6f6E03DEe6F18F9e0E56E19fF6267 src/Projects.sol:Projects --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x57A53806Ac17777Efbe26ffaA352311fE9Fc70A6 src/Creators.sol:Creators --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x02b232c43d8dd8a315c14224648dbeED0a100c21 src/Raises.sol:Raises --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0xE0987f8081CB11Bc8512989Ca9C650c6c47Acba3 src/Metadata.sol:Metadata --constructor-args 0x00000000000000000000000097e89840d02dd999a1ac089fbcf9f8399e8653d4000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000003b4642507b1e9b4bc5ebfe75a97826a1c59d94c0000000000000000000000000000000000000000000000000000000000000003a68747470733a2f2f7777772e73746167696e672d656e7465727461696e6d696e742e636f6d2f6170692f6d657461646174612f746f6b656e732f000000000000000000000000000000000000000000000000000000000000000000000000003d68747470733a2f2f7777772e73746167696e672d656e7465727461696e6d696e742e636f6d2f6170692f6d657461646174612f636f6e7472616374732f000000 $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x98Ef7f4c2985A8B1363343836d863474aBA4cEE8 src/Royalties.sol:Royalties --constructor-args 0x00000000000000000000000097e89840d02dd999a1ac089fbcf9f8399e8653d40000000000000000000000003b4642507b1e9b4bc5ebfe75a97826a1c59d94c0 $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0xf585ce7187eb5d6aB22fa440E88b076499D95970 src/Minter.sol:Minter --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x3b76e61EF0D78d90850A35Da727C8c5c7847B83e src/TokenDeployer.sol:TokenDeployer --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0xE95c60907282f46dEef7650d013cD1e6C11D4117 src/Tokens.sol:Tokens --constructor-args $CONTROLLER_ADDR $ETHERSCAN_API_KEY
forge verify-contract --chain 5 0x20C159cA6fEEeFcB96466f1F6D92e79EB7F03cC8 src/tokens/Emint1155.sol:Emint1155 $ETHERSCAN_API_KEY