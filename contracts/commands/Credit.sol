// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "./Base.sol";
import {BALANCES, SETUP} from "../utils/Channels.sol";
import {BlockRef, RECIPIENT} from "../blocks/Schema.sol";
import {Blocks} from "../blocks/Readers.sol";
string constant NAME = "creditBalanceToAccount";

using Blocks for BlockRef;

abstract contract CreditBalanceToAccount is CommandBase {
    uint internal immutable creditBalanceToAccountId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, RECIPIENT, creditBalanceToAccountId, BALANCES, SETUP);
    }

    /// @dev Override to credit externally managed funds to `account`.
    /// Called once per BALANCE block in state.
    function creditAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function creditBalanceToAccount(
        CommandContext calldata c
    ) external payable onlyCommand(creditBalanceToAccountId, c.target) returns (bytes memory) {
        bytes32 to = Blocks.resolveRecipient(c.request, 0, c.request.length, c.account);
        uint i = 0;
        while (i < c.state.length) {
            BlockRef memory ref = Blocks.from(c.state, i);
            if (!ref.isBalance()) break;
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackBalance(c.state);
            creditAccount(to, asset, meta, amount);
            i = ref.end;
        }

        return done(0, i);
    }
}
