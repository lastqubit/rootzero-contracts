// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES, CUSTODIES, SETUP} from "../utils/Channels.sol";
import {AMOUNT, AMOUNT_KEY, BALANCE_KEY, NODE} from "../blocks/Schema.sol";
import {Blocks, BlockRef, Writers, Writer} from "../Blocks.sol";
using Blocks for BlockRef;
using Writers for Writer;

string constant PROVISION = "provision";
string constant PFB = "provisionFromBalance";

string constant REQUEST = string.concat(AMOUNT, ">", NODE);

abstract contract ProvisionBase {
    /// @dev Override this hook to send or provision funds to `host`.
    /// Called by both `Provision` and `ProvisionFromBalance`.
    /// Implementations should only perform the side effect and must not
    /// encode or append output blocks.
    function provision(bytes32 account, uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;
}

abstract contract Provision is CommandBase, ProvisionBase {
    uint internal immutable provisionId = commandId(PROVISION);

    constructor() {
        emit Command(host, PROVISION, REQUEST, provisionId, SETUP, CUSTODIES);
    }

    function provision(
        CommandContext calldata c
    ) external payable onlyCommand(provisionId, c.target) returns (bytes memory) {
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocCustodiesFrom(c.request, q, AMOUNT_KEY);

        while (q < end) {
            BlockRef memory ref = Blocks.from(c.request, q);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount(c.request);
            uint toHost = ref.innerNode(c.request);
            provision(c.account, toHost, asset, meta, amount);
            writer.appendCustody(toHost, asset, meta, amount);
            q = ref.end;
        }

        return writer.done();
    }
}

// @dev Converts BALANCE state into CUSTODY state for a destination host.
abstract contract ProvisionFromBalance is CommandBase, ProvisionBase {
    uint internal immutable provisionFromBalanceId = commandId(PFB);

    constructor() {
        emit Command(host, PFB, NODE, provisionFromBalanceId, BALANCES, CUSTODIES);
    }

    function provisionFromBalance(
        CommandContext calldata c
    ) external payable onlyCommand(provisionFromBalanceId, c.target) returns (bytes memory) {
        uint toHost = Blocks.resolveNode(c.request, 0, c.request.length, 0);
        uint i = 0;
        (Writer memory writer, uint end) = Writers.allocCustodiesFrom(c.state, i, BALANCE_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.from(c.state, i);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackBalance(c.state);
            provision(c.account, toHost, asset, meta, amount);
            writer.appendCustody(toHost, asset, meta, amount);
            i = ref.end;
        }

        return writer.done();
    }
}
