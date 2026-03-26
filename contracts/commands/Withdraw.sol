// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase } from "./Base.sol";
import { BALANCES, SETUP } from "../utils/Channels.sol";
import { Keys } from "../blocks/Keys.sol";
import { Schemas } from "../blocks/Schema.sol";
import { Blocks, Block, Keys } from "../Blocks.sol";
using Blocks for Block;

string constant NAME = "withdraw";

// @dev Use `withdraw` for externally delivered assets; use `creditBalanceToAccount` for internal balance credits.
abstract contract Withdraw is CommandBase {
    uint internal immutable withdrawId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Recipient, withdrawId, BALANCES, SETUP);
    }

    /// @dev Override to send funds to `account`.
    /// Called once per BALANCE block in state.
    function withdraw(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function withdraw(
        CommandContext calldata c
    ) external payable onlyCommand(withdrawId, c.target) returns (bytes memory) {
        bytes32 to = Blocks.resolveRecipient(c.request, 0, c.request.length, c.account);
        uint i = 0;
        while (i < c.state.length) {
            Block memory ref = Blocks.from(c.state, i);
            if (ref.key != Keys.Balance) break;
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackBalance();
            withdraw(to, asset, meta, amount);
            i = ref.cursor;
        }

        return done(0, i);
    }
}
