// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Controllable} from "./abstract/Controllable.sol";
import {IRoyalties} from "./interfaces/IRoyalties.sol";
import {IControllable} from "./interfaces/IControllable.sol";
import {TokenData, TokenType} from "./structs/TokenData.sol";
import {RaiseData, TierType} from "./structs/RaiseData.sol";
import {RaiseToken} from "./libraries/RaiseToken.sol";

uint256 constant BPS_DENOMINATOR = 10_000;

/// @title Royalties - Royalty registry
/// @notice Calculates ERC-2981 token royalties.
contract Royalties is IRoyalties, Controllable {
    using RaiseToken for uint256;

    string public constant NAME = "Royalties";
    string public constant VERSION = "0.0.1";

    address public receiver;

    constructor(address _controller, address _receiver) Controllable(_controller) {
        if (_receiver == address(0)) revert ZeroAddress();
        receiver = _receiver;
    }

    /// @inheritdoc IRoyalties
    function royaltyInfo(uint256 tokenId, uint256 salePrice) public view override returns (address, uint256) {
        uint256 feeBps;

        (TokenData memory token, RaiseData memory raise) = tokenId.decode();
        if (token.tokenType == TokenType.Raise) {
            if (raise.tierType == TierType.Fan) {
                feeBps = 150;
            }
            if (raise.tierType == TierType.Brand) {
                feeBps = 1000;
            }
        }
        uint256 royalty = (feeBps * salePrice) / BPS_DENOMINATOR;
        return (receiver, royalty);
    }

    /// @inheritdoc IControllable
    function setDependency(bytes32 _name, address _contract)
        external
        override (Controllable, IControllable)
        onlyController
    {
        if (_contract == address(0)) revert ZeroAddress();
        else if (_name == "receiver") _setReceiver(_contract);
    }

    function _setReceiver(address _receiver) internal {
        emit SetReceiver(receiver, _receiver);
        receiver = _receiver;
    }
}
