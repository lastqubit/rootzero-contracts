// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Data} from "../Utils/Data.sol";

uint16 constant DENOMINATOR = 10_000;

// step: endpoint:value:req:?(validator:deadline:from:sig)

function calcBps(uint amount, uint16 bps) pure returns (uint) {
    if (amount == 0 || bps == 0) return 0;
    return (amount * bps) / DENOMINATOR;
}

function reverse(uint amount, uint16 bps) pure returns (uint) {
    if (amount == 0 || bps == 0) return 0;
    return (amount * DENOMINATOR) / (DENOMINATOR + bps);
}

