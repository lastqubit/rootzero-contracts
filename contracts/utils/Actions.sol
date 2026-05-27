// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

library Actions {
    uint32 constant None = 0;
    uint32 constant Transfer = 1;
    uint32 constant Deposit = 2;
    uint32 constant Withdraw = 3;
    uint32 constant Fee = 4;
    uint32 constant Mint = 5;
    uint32 constant Burn = 6;
    uint32 constant Swap = 7;
    uint32 constant Borrow = 8;
    uint32 constant Repay = 9;
    uint32 constant Liquidate = 10;
}
