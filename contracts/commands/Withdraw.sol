// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Keys, Lanes, Specs} from "./Base.sol";
using Executions for Execution;

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
abstract contract Withdraw is CommandBase, WithdrawHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("withdraw", Specs.Balance, Specs.Empty, Specs.Empty, 0, false, false);
    }

    /// @notice Withdraw each BALANCE block from the command state to the command account.
    /// @param state BALANCE block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function withdraw(
        bytes32 account,
        bytes calldata state,
        bytes calldata
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openState(state, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackBalance(Lanes.State);
            withdraw(account, asset, amount);
        }

        return closeCommand(exec, account);
    }
}
