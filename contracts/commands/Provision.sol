// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, CUSTODIES, SETUP} from "./Base.sol";
import {HostAmount, AMOUNT, AMOUNT_KEY, NODE} from "../blocks/Schema.sol";
import {Blocks, BlockRef, Writers, Writer} from "../Blocks.sol";
using Blocks for BlockRef;
using Writers for Writer;

bytes32 constant NAME = "provision";
string constant REQUEST = string.concat(AMOUNT, ">", NODE);

abstract contract Provision is CommandBase {
    uint internal immutable provisionId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, REQUEST, provisionId, SETUP, CUSTODIES);
    }

    function provision(
        uint host,
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) internal virtual returns (HostAmount memory);

    function provision(
        CommandContext calldata c
    ) external payable onlyCommand(provisionId, c.target) returns (bytes memory) {
        uint i = 0;
        (Writer memory writer, uint end) = Writers.allocCustodiesFrom(c.request, i, AMOUNT_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.amountFrom(c.request, i);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount(c.request);
            uint h = ref.innerNode(c.request);
            HostAmount memory out = provision(h, c.account, asset, meta, amount);
            if (out.amount > 0) writer.appendCustody(out);
            i = ref.end;
        }

        return writer.finish();
    }
}
