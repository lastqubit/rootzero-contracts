// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES, CUSTODIES} from "../utils/Channels.sol";
import {BALANCE_KEY, Blocks, BlockRef, NODE, Writers, Writer} from "../Blocks.sol";
using Blocks for BlockRef;
using Writers for Writer;

string constant NAME = "fund";

// @dev Converts BALANCE state into CUSTODY state for a destination host.
abstract contract Fund is CommandBase {
    uint internal immutable fundId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, NODE, fundId, BALANCES, CUSTODIES);
    }

    function fund(uint host, bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function fund(CommandContext calldata c) external payable onlyCommand(fundId, c.target) returns (bytes memory) {
        uint h = Blocks.resolveNode(c.request, 0, c.request.length, 0);
        uint i = 0;
        (Writer memory writer, uint end) = Writers.allocCustodiesFrom(c.state, i, BALANCE_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.from(c.state, i);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackBalance(c.state);
            fund(h, c.account, asset, meta, amount);
            writer.appendCustody(h, asset, meta, amount);
            i = ref.end;
        }

        return writer.done();
    }
}
