// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @notice Standard context codes for generic asset activity events.
library Contexts {
    uint constant Deposit = 1;
    uint constant Withdraw = 2;
    uint constant Fee = 3;
    uint constant Mint = 4;
    uint constant Burn = 5;
    uint constant Swap = 6;
}
