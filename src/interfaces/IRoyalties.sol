// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IAnnotated} from "./IAnnotated.sol";
import {IControllable} from "./IControllable.sol";

interface IRoyalties is IControllable, IAnnotated {
    event SetReceiver(address oldReceiver, address newReceiver);

    /// @notice Returns how much royalty is owed and to whom, based on a sale
    /// price that may be denominated in any unit of exchange. The royalty
    /// amount is denominated and should be paid in the same unit of exchange.
    /// @param tokenId uint256 Token ID.
    /// @param salePrice uint256 Sale price (in any unit of exchange).[]
    /// @return receiver address of royalty recipient.
    /// @return royaltyAmount amount of royalty.
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}
