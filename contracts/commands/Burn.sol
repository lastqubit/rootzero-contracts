// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "./Base.sol";
import { Blocks, Block, Keys } from "../Blocks.sol";
using Blocks for Block;

string constant NAME = "burn";

abstract contract Burn is CommandBase {
    uint internal immutable burnId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, "", burnId, Channels.Balances, Channels.Setup);
    }

    /// @dev Override to burn or consume the provided balance amount.
    /// Called once per BALANCE block in state.
    function burn(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual returns (uint);

    function burn(CommandContext calldata c) external payable onlyCommand(burnId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.state.length) {
            Block memory ref = Blocks.from(c.state, i);
            if (ref.key != Keys.Balance) break;
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackBalance();
            burn(c.account, asset, meta, amount);
            i = ref.cursor;
        }

        return done(0, i);
    }
}
