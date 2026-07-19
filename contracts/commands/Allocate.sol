// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, Keys} from "./Base.sol";
import {HostAmount, Cursors, Cur, Writer, Writers} from "../Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

/// @notice Shared allocation hook used by `Allocate`.
abstract contract AllocateHook {
    /// @notice Override to allocate a live balance into custody on a host.
    /// Called once per paired BALANCE state block and NODE request block.
    /// Implementations should perform only the custody side effect; output
    /// blocks are written by the caller.
    /// @param account Caller's account identifier.
    /// @param custody Host-scoped amount to allocate into custody.
    function allocate(bytes32 account, HostAmount memory custody) internal virtual;
}

/// @title Allocate
/// @notice Command that allocates BALANCE state to custody on requested hosts.
/// Each BALANCE state block is paired with one NODE request block at the same
/// position; the output is a matching CUSTODY state stream.
abstract contract Allocate is CommandBase, AllocateHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("allocate", Keys.Balance, Keys.Node, Keys.Custody, 0, false, false);
    }

    /// @notice Allocate BALANCE state blocks to matching NODE request blocks.
    /// @param c Command context; `c.state` must contain BALANCE blocks and
    /// `c.input` must contain the same number of NODE blocks.
    /// @return CUSTODY block stream matching the allocated balances.
    /// @return Empty transaction stream.
    function allocate(CommandContext calldata c) external onlyCommand returns (bytes memory, bytes memory) {
        (Cur memory input, Cur memory state, uint outputs) = openCommand(c, descriptor);
        Writer memory output = Writers.allocCustodies(outputs);

        while (state.i < state.len) {
            HostAmount memory custody = state.unpackBalanceForHost(input.unpackNode());
            allocate(c.account, custody);
            output.appendCustody(custody);
        }

        return (output.finish(), "");
    }
}
