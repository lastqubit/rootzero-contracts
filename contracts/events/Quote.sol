// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Quote(uint indexed host, uint cid, string schema)";

/// @notice Emitted when a price quote or rate is published by a command.
abstract contract QuoteEvent is EventEmitter {
    /// @param host Host node ID publishing the quote.
    /// @param cid Command ID associated with the quote.
    /// @param schema Schema string describing the quote's data layout.
    event Quote(uint indexed host, uint cid, string schema);

    constructor() {
        emit EventAbi(ABI);
    }
}



