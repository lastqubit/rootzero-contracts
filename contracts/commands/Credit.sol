// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "./Base.sol";
import { Cursors, Cursor, Keys, Schemas } from "../Cursors.sol";
string constant NAME = "creditAccount";

using Cursors for Cursor;

abstract contract CreditAccount is CommandBase {
    uint internal immutable creditAccountId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Recipient, creditAccountId, Channels.Balances, Channels.Setup);
    }

    /// @dev Override to credit externally managed funds to `account`.
    /// Called once per BALANCE block in state.
    function creditAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function creditAccount(
        CommandContext calldata c
    ) external payable onlyCommand(creditAccountId, c.target) returns (bytes memory) {
        bytes32 to = Cursors.resolveRecipient(c.request, 0, c.request.length, c.account);
        Cursor memory balances = Cursors.openRun(c.state, 0, Keys.Balance, 1);
        while (balances.i < balances.end) {
            (bytes32 asset, bytes32 meta, uint amount) = balances.unpackBalance();
            creditAccount(to, asset, meta, amount);
        }

        return balances.complete();
    }
}




