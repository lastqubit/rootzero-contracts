// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, CommandContext, Keys} from "./Base.sol";
import {Cursors, Cur} from "../../Cursors.sol";
using Cursors for Cur;

/// @title PublishSchema
/// @notice Admin command that publishes block schemas for keys.
/// Each SCHEMA block in the request emits one `Schema` event. Only callable by
/// the admin account.
abstract contract PublishSchema is AdminBase {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("publishSchema", Keys.Empty, Keys.Schema, Keys.Empty, 0, false, true);
    }

    /// @notice Publish each SCHEMA block in the admin request.
    /// @param c Admin command context; `c.input` must contain SCHEMA blocks.
    /// @return state Empty output state.
    /// @return transactions Empty transaction stream.
    function publishSchema(CommandContext calldata c) external onlyAdmin(c.account) returns (bytes memory state, bytes memory transactions) {
        (Cur memory input, ) = openInput(c.input, descriptor);

        while (input.i < input.len) {
            (bytes4 key, string memory body, bytes32 name) = input.unpackSchema();
            emit Schema(host, key, body, name);
        }
        return ("", "");
    }
}
