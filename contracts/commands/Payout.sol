// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Lanes, Specs} from "./Base.sol";
import {Action} from "../annotations/Action.sol";
import {Actions} from "../utils/Actions.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that pay balances to accounts.
abstract contract PayoutHook {
    /// @notice Override to pay `amount` from `account` to `to`.
    /// Called once per paired BALANCE state block and ACCOUNT input block.
    /// @param account Source account identifier.
    /// @param to Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Amount to pay out.
    function payout(bytes32 account, bytes32 to, bytes32 asset, uint amount) internal virtual;
}

/// @title Payout
/// @notice Command that sinks BALANCE state blocks to matching ACCOUNT input blocks.
/// Each BALANCE block is paired with one ACCOUNT block at the same position.
abstract contract Payout is CommandBase, PayoutHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("payout", Specs.Balance, Specs.Account, Specs.Empty, 0, false, false);
        action(id, Actions.Payout);
    }

    /// @notice Pay out BALANCE state blocks to matching ACCOUNT input blocks.
    /// @param state BALANCE block stream.
    /// @param input Matching ACCOUNT block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function payout(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackBalance(Lanes.State);
            payout(account, exec.unpackAccount(Lanes.Input), asset, amount);
        }

        return close(exec, account);
    }
}
