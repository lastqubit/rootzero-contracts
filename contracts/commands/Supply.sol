// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, CUSTODIES, SETUP} from "./Base.sol";
import {Blocks, BlockRef, HostAmount} from "../Blocks.sol";
bytes32 constant NAME = "supply";

using Blocks for BlockRef;

abstract contract Supply is CommandBase {
    uint internal immutable supplyId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, "", supplyId, CUSTODIES, SETUP);
    }

    function supply(bytes32 account, HostAmount memory value) internal virtual;

    function supply(CommandContext calldata c) external payable onlyCommand(supplyId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.state.length) {
            BlockRef memory ref = Blocks.from(c.state, i);
            if (!ref.isCustody()) break;
            HostAmount memory value = ref.toCustodyValue(c.state);
            supply(c.account, value);
            i = ref.end;
        }

        return done(0, i);
    }
}
