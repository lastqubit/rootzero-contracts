// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @notice Standard context codes for generic asset activity events.
library Contexts {
    uint constant Swap = 1;
    uint constant Deposit = 2;
    uint constant Withdraw = 3;
    uint constant Fee = 4;
    uint constant Mint = 5;
    uint constant Burn = 6;
}
