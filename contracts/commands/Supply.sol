// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext } from "./Base.sol";
import { CUSTODIES, SETUP } from "../utils/Channels.sol";
import { Blocks, Block, HostAmount, Keys } from "../Blocks.sol";
string constant NAME = "supply";

using Blocks for Block;

abstract contract Supply is CommandBase {
    uint internal immutable supplyId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, "", supplyId, CUSTODIES, SETUP);
    }

    /// @dev Override to consume or supply a single custody position.
    /// Called once per CUSTODY block in state.
    function supply(bytes32 account, HostAmount memory value) internal virtual;

    function supply(CommandContext calldata c) external payable onlyCommand(supplyId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.state.length) {
            Block memory ref = Blocks.from(c.state, i);
            if (ref.key != Keys.Custody) break;
            HostAmount memory value = ref.toCustodyValue();
            supply(c.account, value);
            i = ref.cursor;
        }

        return done(0, i);
    }
}
