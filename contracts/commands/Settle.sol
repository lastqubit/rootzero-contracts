// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Lanes, Specs} from "./Base.sol";
import {SettleHook} from "../core/Settlement.sol";
import {Action} from "../annotations/Action.sol";
import {Actions} from "../utils/Actions.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Reader, Readers} from "../codec/Readers.sol";

using Executions for Execution;
using Readers for Reader;

/// @notice Hook implemented by hosts that settle positions using native value.
abstract contract SettlePayableHook {
    /// @notice Override to settle one position for `account` with a shared value budget.
    /// @param account Account whose position is being settled.
    /// @param asset Identifier for the asset side.
    /// @param amount Quantity on the asset side.
    /// @param liability Identifier for the liability side.
    /// @param debt Quantity on the liability side.
    /// @param funds Mutable execution used only for its remaining native-value budget.
    function settle(
        bytes32 account,
        bytes32 asset,
        uint amount,
        bytes32 liability,
        uint debt,
        Execution memory funds
    ) internal virtual;
}

/// @title Settle
/// @notice Command that consumes POSITION state blocks through a virtual hook.
abstract contract Settle is CommandBase, SettleHook, Action {
    uint private immutable descriptor;
    uint private immutable id;

    constructor() {
        (id, descriptor) = command("settle", Specs.Position, Specs.Empty, Specs.Empty, 0, false, false);
        action(id, Actions.Settle);
    }

    /// @notice Return the registered SETTLE command ID.
    function settleId() internal view returns (uint) {
        return id;
    }

    /// @notice Settle each POSITION block from the command state.
    /// @param state POSITION block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function settle(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount, bytes32 liability, uint debt) = exec.unpackPosition(Lanes.State);
            settle(account, asset, amount, liability, debt);
        }

        return close(exec, account);
    }
}

/// @title SettlePayable
/// @notice Funded command that consumes POSITION state blocks through a virtual hook.
abstract contract SettlePayable is CommandBase, SettlePayableHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("settlePayable", Specs.Position, Specs.Empty, Specs.Empty, 0, true, false);
        action(id, Actions.Settle);
    }

    /// @notice Settle each POSITION block with access to a shared native-value budget.
    /// @param state POSITION block stream.
    /// @return Empty output state.
    /// @return Remaining native value as a refund transaction stream.
    function settlePayable(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external payable onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount, bytes32 liability, uint debt) = exec.unpackPosition(Lanes.State);
            settle(account, asset, amount, liability, debt, exec);
        }

        return close(exec, account);
    }
}

/// @title InternalSettle
/// @notice Extends the advertised settle command with memory-state pipeline dispatch.
/// @dev This adapter is not a separate command. It uses the command ID and settlement hook
/// inherited from `Settle` while accepting the state location used by `Pipeline`.
abstract contract InternalSettle is Settle {
    /// @notice Execute the inherited settle command from an internal pipeline.
    /// @param account Account for which each position is settled.
    /// @param state POSITION block stream held in pipeline memory.
    /// @param input Empty input required by the command schema.
    /// @param value Native value assigned to the command; must be zero.
    /// @return output Empty output state.
    /// @return transactions Empty transaction stream.
    function executeSettle(
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint128 value
    ) internal returns (bytes memory, bytes memory) {
        if (value != 0) revert ValueNotAllowed();
        if (input.length != 0) revert Executions.ZeroStride();
        if (state.length == 0) revert Blocks.EmptyRun();

        Reader memory reader = Readers.open(state);
        while (reader.more()) {
            (bytes32 asset, uint amount, bytes32 liability, uint debt) = reader.unpackPosition();
            settle(account, asset, amount, liability, debt);
        }

        return ("", "");
    }
}
