// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Aggregator: re-exports all utility libraries (State, Accounts, Assets, ECDSA, Ids, Layout, Utils, Value).
// Import this file to access the full utility surface without managing individual paths.

import { State } from "./utils/State.sol";
import { Accounts } from "./utils/Accounts.sol";
import { Amounts, Assets } from "./utils/Assets.sol";
import { ECDSA } from "./utils/ECDSA.sol";
import { Ids, Selectors } from "./utils/Ids.sol";
import { Layout } from "./utils/Layout.sol";
import { Schemas } from "./blocks/Schema.sol";
import { addrOr, applyBps, beforeBps, bytes32ToString, divisible, isFamily, isLocal, isLocalFamily, matchesBase, MAX_BPS, max8, max16, max24, max32, max40, max64, max96, max128, max160, NotDivisible, toLocalBase, toLocalFamily, toUnspecifiedBase, ValueOverflow } from "./utils/Utils.sol";
import { Values } from "./utils/Value.sol";



