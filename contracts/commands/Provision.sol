// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, Cursors, Cur, Keys, Schemas, Writer, Writers } from "../Cursors.sol";
using Cursors for Cur;
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
        (Cur memory request, uint count) = cursor(c.request, 1);
        (bytes4 key, ) = request.peek(0);
        if (key != Keys.Bundle) revert Writers.EmptyRequest();
        Writer memory writer = Writers.allocCustodies(count);

        while (request.i < request.bound) {
            Cur memory input = request.bundle();
            uint toHost = input.unpackNode();
            (bytes32 asset, bytes32 meta, uint amount) = input.unpackAmount();
            provision(c.account, toHost, asset, meta, amount);
            writer.appendCustody(toHost, asset, meta, amount);
        }

        return request.complete(writer);
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
        (Cur memory state, uint stateCount) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        uint toHost = request.nodeAfter(0);
        if (toHost == 0) revert Cursors.ZeroNode();
        Writer memory writer = Writers.allocCustodies(stateCount);

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            provision(c.account, toHost, balance.asset, balance.meta, balance.amount);
            writer.appendCustody(toHost, balance.asset, balance.meta, balance.amount);
        }

        return state.complete(writer);
    }
}






