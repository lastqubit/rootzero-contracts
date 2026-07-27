// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Keys, Lanes, Specs} from "./Base.sol";
using Executions for Execution;

/// @title PublishSchema
/// @notice Admin command that publishes block schemas for keys.
/// Each SCHEMA block in the request emits one `Schema` event. Only callable by
/// the admin account.
abstract contract PublishSchema is AdminBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("publishSchema", Specs.Empty, Specs.Schema, Specs.Empty, 0, false, true);
    }

    /// @notice Publish each SCHEMA block in the admin request.
    /// @param input SCHEMA block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function publishSchema(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external onlyAdmin(account) returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            (uint spec, string memory body, bytes32 name) = exec.unpackSchema(Lanes.Input);
            emit Schema(host, spec, body, name);
        }

        return closeCommand(exec, account);
    }
}
