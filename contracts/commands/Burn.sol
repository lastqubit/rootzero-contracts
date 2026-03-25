// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "./Base.sol";
import {BALANCES, SETUP} from "../utils/Channels.sol";
import {Blocks, BlockRef} from "../Blocks.sol";
using Blocks for BlockRef;

string constant NAME = "burn";

abstract contract Burn is CommandBase {
    uint internal immutable burnId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, burnId, BALANCES, SETUP);
    }

    function burn(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual returns (uint);

    function burn(CommandContext calldata c) external payable onlyCommand(burnId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.state.length) {
            BlockRef memory ref = Blocks.from(c.state, i);
            if (!ref.isBalance()) break;
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackBalance(c.state);
            burn(c.account, asset, meta, amount);
            i = ref.end;
        }

        return done(0, i);
    }
}
