// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, State} from "./Base.sol";
import {Cursors, Cur, Keys, Schemas, Writer, Writers} from "../Cursors.sol";
using Cursors for Cur;
using Writers for Writer;

string constant PROVISION = "provision";
string constant PFB = "provisionFromBalance";

string constant INPUT = string.concat(Schemas.Node, "&", Schemas.Amount);

/// @notice Shared provision hook used by both `Provision` and `ProvisionFromBalance`.
abstract contract ProvisionHook {
    /// @notice Override to send or provision funds to `host`.
    /// Called once per provisioned asset. Implementations should perform only the
    /// side effect (e.g. transfer or record); output blocks are written by the caller.
    /// @param account Caller's account identifier.
    /// @param host Destination host node ID.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount to provision.
    function provision(bytes32 account, uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;
}

/// @title Provision
/// @notice Command that provisions assets to remote hosts from bundled NODE+AMOUNT request blocks.
/// Each bundle contains a target node ID and an amount; the output is a CUSTODY state stream.
abstract contract Provision is CommandBase, ProvisionHook {
    uint internal immutable provisionId = commandId(PROVISION);

    constructor() {
        emit Command(host, PROVISION, INPUT, provisionId, State.Empty, State.Custodies);
    }

    function provision(
        CommandContext calldata c
    ) external payable onlyCommand(provisionId, c.target) returns (bytes memory) {
        (Cur memory request, uint count, ) = cursor(c.request, 1);
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

/// @title ProvisionFromBalance
/// @notice Command that converts BALANCE state into CUSTODY state for a destination host.
/// The destination node is read from an optional NODE trailing block; reverts if absent.
abstract contract ProvisionFromBalance is CommandBase, ProvisionHook {
    uint internal immutable provisionFromBalanceId = commandId(PFB);

    constructor() {
        emit Command(host, PFB, Schemas.Node, provisionFromBalanceId, State.Balances, State.Custodies);
    }

    function provisionFromBalance(
        CommandContext calldata c
    ) external payable onlyCommand(provisionFromBalanceId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocCustodies(stateCount);
        uint toHost = request.nodeAfter(0);
        if (toHost == 0) revert Cursors.ZeroNode();

        while (state.i < state.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = state.unpackBalance();
            provision(c.account, toHost, asset, meta, amount);
            writer.appendCustody(toHost, asset, meta, amount);
        }

        return state.complete(writer);
    }
}
