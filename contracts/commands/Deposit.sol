// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { Cursors, Cur, Schemas, Writer, Writers, Writers2 } from "../Cursors.sol";

string constant NAME = "deposit";

using Cursors for Cur;
using Writers for Writer;
using Writers2 for Cur;

// @dev Use `deposit` for externally sourced assets; use `debitAccountToBalance` for internal balance deductions.
abstract contract Deposit is CommandBase {
    uint internal immutable depositId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Amount, depositId, Channels.Setup, Channels.Balances);
    }

    /// @dev Override to receive externally sourced funds for `account`.
    /// Called once per AMOUNT block and followed by a matching BALANCE output.
    function deposit(
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) internal virtual;

    function deposit(
        CommandContext calldata c
    ) external payable onlyCommand(depositId, c.target) returns (bytes memory) {
        Cur memory request = cursor(c.request, 1);
        Writer memory writer = request.allocBalances();

        while (request.i < request.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = request.unpackAmount();
            deposit(c.account, asset, meta, amount);
            writer.appendBalance(asset, meta, amount);
        }

        return request.complete(writer);
    }
}





