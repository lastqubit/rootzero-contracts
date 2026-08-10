// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Aggregator: re-exports protocol identifier, asset, account, cryptographic,
// layout, and general-purpose utility helpers.
// Import this file to access the full utility surface without managing individual paths.

import { Accounts } from "./utils/Accounts.sol";
import { Actions } from "./utils/Actions.sol";
import { Amounts, Assets } from "./utils/Assets.sol";
import { ECDSA } from "./utils/ECDSA.sol";
import { Ids } from "./utils/Ids.sol";
import { Nodes } from "./utils/Nodes.sol";
import { Selectors } from "./utils/Selectors.sol";
import { Layout } from "./utils/Layout.sol";
import { addrOr, applyBps, beforeBps, bytes32ToInt, bytes32ToString, clear8, clear16, clear32, clear64, divisible, ensureAddr, hash32, intToBytes32, isFamily, matchesBase, MAX_BPS, max8, max16, max24, max32, max40, max64, max96, max128, max160, NotDivisible, replace8, replace16, replace32, replace64, retryTicket, toLocalBase, toUnspecifiedBase, ValueOverflow, ZeroAddress } from "./utils/Utils.sol";



