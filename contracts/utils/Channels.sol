// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

library Channels {
    uint8 constant Setup = 0x0001;
    uint8 constant Pipe = 0x0002;
    uint8 constant Balances = 0x0003;
    uint8 constant Transactions = 0x0004;
    uint8 constant Custodies = 0x0005;
    uint8 constant Claims = 0x0006;
}
