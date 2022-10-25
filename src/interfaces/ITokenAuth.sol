// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IAllowList} from "./IAllowList.sol";
import {IAnnotated} from "./IAnnotated.sol";

interface ITokenAuth is IAllowList, IAnnotated {}
