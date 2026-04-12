// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, State } from "./Base.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";
string constant NAME = "creditAccount";

using Cursors for Cur;

/// @title CreditAccount
/// @notice Command that delivers BALANCE state blocks to an account via a virtual hook.
/// Use for internally recording credits that have already been settled externally.
/// An optional RECIPIENT block in the request overrides the default `c.account` destination.
abstract contract CreditAccount is CommandBase {
    uint internal immutable creditAccountId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Recipient, creditAccountId, State.Balances, State.Empty);
    }

    /// @notice Override to credit externally managed funds to `account`.
    /// Called once per BALANCE block in state.
    /// @param account Recipient account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount to credit.
    function creditAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function creditAccount(
        CommandContext calldata c
    ) external payable onlyCommand(creditAccountId, c.target) returns (bytes memory) {
        (Cur memory state, , ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        bytes32 to = request.recipientAfter(c.account);

        while (state.i < state.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = state.unpackBalance();
            creditAccount(to, asset, meta, amount);
        }

        state.complete();
        return "";
    }
}





