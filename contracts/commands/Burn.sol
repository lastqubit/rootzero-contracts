// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "./Base.sol";
import {BALANCES, SETUP} from "../utils/Channels.sol";
import {BALANCE_KEY, Data, DataRef} from "../Blocks.sol";
using Data for DataRef;

string constant NAME = "burn";

abstract contract Burn is CommandBase {
    uint internal immutable burnId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, burnId, BALANCES, SETUP);
    }

    /// @dev Override to burn or consume the provided balance amount.
    /// Called once per BALANCE block in state.
    function burn(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual returns (uint);

    function burn(CommandContext calldata c) external payable onlyCommand(burnId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.state.length) {
            DataRef memory ref = Data.from(c.state, i);
            if (ref.key != BALANCE_KEY) break;
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackBalance();
            burn(c.account, asset, meta, amount);
            i = ref.cursor;
        }

        return done(0, i);
    }
}
