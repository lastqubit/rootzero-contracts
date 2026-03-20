// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, BALANCES, SETUP} from "./Base.sol";
import {BlockRef, RECIPIENT} from "../blocks/Schema.sol";
import {Blocks} from "../blocks/Readers.sol";
using Blocks for BlockRef;

bytes32 constant NAME = "withdraw";

// @dev Use `withdraw` for externally delivered assets; use `creditBalanceToAccount` for internal balance credits.
abstract contract Withdraw is CommandBase {
    uint internal immutable withdrawId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, RECIPIENT, withdrawId, BALANCES, SETUP);
    }

    function withdraw(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function withdraw(
        CommandContext calldata c
    ) external payable onlyCommand(withdrawId, c.target) returns (bytes memory) {
        bytes32 to = Blocks.resolveRecipient(c.request, 0, c.request.length, c.account);
        uint i = 0;
        while (i < c.state.length) {
            BlockRef memory ref = Blocks.from(c.state, i);
            if (!ref.isBalance()) break;
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackBalance(c.state);
            withdraw(to, asset, meta, amount);
            i = ref.end;
        }

        return done(0, i);
    }
}
