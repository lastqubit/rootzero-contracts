// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { Cursors, Cursor, Keys, Schemas, Writer, Writers } from "../Cursors.sol";
using Cursors for Cursor;
using Writers for Writer;

string constant PROVISION = "provision";
string constant PFB = "provisionFromBalance";

string constant INPUT = string.concat(Schemas.Node, "&", Schemas.Amount);

abstract contract ProvisionHook {
    /// @dev Override this hook to send or provision funds to `host`.
    /// Called by both `Provision` and `ProvisionFromBalance`.
    /// Implementations should only perform the side effect and must not
    /// encode or append output blocks.
    function provision(bytes32 account, uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;
}

abstract contract Provision is CommandBase, ProvisionHook {
    uint internal immutable provisionId = commandId(PROVISION);

    constructor() {
        emit Command(host, PROVISION, INPUT, provisionId, Channels.Setup, Channels.Custodies);
    }

    function provision(
        CommandContext calldata c
    ) external payable onlyCommand(provisionId, c.target) returns (bytes memory) {
        (Cursor memory inputs, uint count) = Cursors.openRun(c.request, 0, Keys.Bundle);
        Writer memory writer = Writers.allocCustodies(count);

        while (inputs.i < inputs.end) {
            Cursor memory input = inputs.take();
            uint toHost = input.unpackNode();
            (bytes32 asset, bytes32 meta, uint amount) = input.unpackAmount();
            provision(c.account, toHost, asset, meta, amount);
            writer.appendCustody(toHost, asset, meta, amount);
        }

        return writer.done();
    }
}

// @dev Converts BALANCE state into CUSTODY state for a destination host.
abstract contract ProvisionFromBalance is CommandBase, ProvisionHook {
    uint internal immutable provisionFromBalanceId = commandId(PFB);

    constructor() {
        emit Command(host, PFB, Schemas.Node, provisionFromBalanceId, Channels.Balances, Channels.Custodies);
    }

    function provisionFromBalance(
        CommandContext calldata c
    ) external payable onlyCommand(provisionFromBalanceId, c.target) returns (bytes memory) {
        uint toHost = Cursors.resolveNode(c.request, 0, c.request.length, 0);
        (Cursor memory balances, uint count) = Cursors.openRun(c.state, 0, Keys.Balance);
        Writer memory writer = Writers.allocCustodies(count);

        while (balances.i < balances.end) {
            (bytes32 asset, bytes32 meta, uint amount) = balances.unpackBalance();
            provision(c.account, toHost, asset, meta, amount);
            writer.appendCustody(toHost, asset, meta, amount);
        }

        return writer.done();
    }
}




