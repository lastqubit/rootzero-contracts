// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Lanes, Specs} from "./Base.sol";
import {Action} from "../annotations/Action.sol";
import {Actions} from "../utils/Actions.sol";
using Executions for Execution;

/// @notice Hook implemented by hosts that withdraw account balances.
abstract contract WithdrawHook {
    /// @notice Override to send funds to `account`.
    /// Called once per BALANCE block in state.
    /// @param account Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Amount to deliver.
    function withdraw(bytes32 account, bytes32 asset, uint amount) internal virtual;
}

/// @title Withdraw
/// @notice Command that delivers BALANCE state blocks to an external destination.
/// Use `withdraw` for assets being sent outside the protocol (e.g. ERC-20 transfers, ETH sends).
/// For internal balance credits, use `creditAccount` instead.
abstract contract Withdraw is CommandBase, WithdrawHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("withdraw", Specs.Balance, Specs.Empty, Specs.Empty, 0, false, false);
        action(id, Actions.Withdraw);
    }

    /// @notice Withdraw each BALANCE block from the command state to the command account.
    /// @param state BALANCE block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function withdraw(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackBalance(Lanes.State);
            withdraw(account, asset, amount);
        }

        return close(exec, account);
    }
}
