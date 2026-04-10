// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "./Base.sol";
import { Cursors, Cur, AssetAmount, Schemas } from "../Cursors.sol";
string constant NAME = "creditAccount";

using Cursors for Cur;

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
        (Cur memory state, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        bytes32 to = request.recipientAfter(c.account);

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            creditAccount(to, balance.asset, balance.meta, balance.amount);
        }

        state.complete();
        return "";
    }
}





