// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Aggregator: re-exports query abstractions.
// Import this file to build rootzero query contracts without managing individual paths.

import { QueryBase, encodeQueryCall } from "./queries/Base.sol";
