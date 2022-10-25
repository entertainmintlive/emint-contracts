// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Pausable as OZPausable} from "openzeppelin-contracts/security/Pausable.sol";
import {IPausable} from "../interfaces/IPausable.sol";

/// @title Pausable - Pause and unpause functionality
/// @notice Wraps OZ Pausable and adds an IPausable interface.
abstract contract Pausable is IPausable, OZPausable {}
