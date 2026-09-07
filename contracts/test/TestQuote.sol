// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Blocks, Cur, Decoders, Position, Specs, Writer, Writers} from "../Codec.sol";
import {Execution, Executions} from "../execution/Execution.sol";
import {Positions} from "../utils/Positions.sol";

contract TestQuote {
    using Decoders for Cur;
    using Writers for Writer;
    using Executions for Execution;

    function check(bytes calldata input, Position memory position) external pure returns (Position memory next) {
        Cur memory cur = Decoders.open(input);
        Positions.requireQuoted(position, cur.unpackQuoteValue());
        return cur.unpackQuoteValue();
    }

    function create(Position memory quote) external pure returns (bytes memory) {
        return Blocks.createQuote(quote.asset, quote.amount, quote.liability, quote.debt, quote.counterparty);
    }

    function write(Position memory quote, bool scalar) external pure returns (bytes memory) {
        Writer memory writer = Writers.init(Specs.Quote, 1);
        if (scalar) writer.appendQuote(quote.asset, quote.amount, quote.liability, quote.debt, quote.counterparty);
        else writer.appendQuote(quote);
        return writer.finish();
    }

    function decode(bytes calldata input, bool scalar) external pure returns (Position memory quote) {
        Cur memory cur = Decoders.open(input);
        if (scalar) (quote.asset, quote.amount, quote.liability, quote.debt, quote.counterparty) = cur.unpackQuote();
        else quote = cur.unpackQuoteValue();
    }

    function execute(bytes calldata state, bytes calldata input, bool scalar) external pure returns (bytes memory) {
        Execution memory exec;
        exec.open(Executions.describe(Specs.Position, Specs.Quote, Specs.Quote, 0), 0, 0, state, input);
        while (exec.more()) {
            exec.unpackPosition();
            if (scalar) {
                (bytes32 asset, uint amount, bytes32 liability, uint debt, bytes32 counterparty) = exec.unpackQuote();
                exec.outputQuote(asset, amount, liability, debt, counterparty);
            } else {
                exec.outputQuote(exec.unpackQuoteValue());
            }
        }
        return exec.finish();
    }
}
