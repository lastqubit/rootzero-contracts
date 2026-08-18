// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Execution, Executions, CommandBase, Lanes, Specs } from "./Base.sol";
import {Action} from "../annotations/Action.sol";
import {Actions} from "../utils/Actions.sol";
using Executions for Execution;

/// @notice Hook implemented by hosts that burn account assets.
abstract contract BurnHook {
    /// @notice Override to burn or consume the provided balance amount.
    /// Called once per BALANCE block in state.
    /// @param account Caller's account identifier.
    /// @param asset Asset identifier.
    /// @param amount Amount to burn.
    /// @return Amount actually burned (may differ from `amount` for partial burns).
    function burn(bytes32 account, bytes32 asset, uint amount) internal virtual returns (uint);
}

/// @title Burn
/// @notice Command that irreversibly destroys each BALANCE state block via a virtual hook.
/// Produces no output state.
abstract contract Burn is CommandBase, BurnHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("burn", Specs.Balance, Specs.Empty, Specs.Empty, 0, 0);
        action(id, Actions.Burn);
    }

    /// @notice Burn each BALANCE block from the command state.
    /// @param state BALANCE block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function burn(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackBalance(Lanes.State);
            burn(account, asset, amount);
        }

        return close(exec, account);
    }
}






