// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract FakeERC20 is IERC20, ERC20("Fake Test Token", "FAKE") {
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
