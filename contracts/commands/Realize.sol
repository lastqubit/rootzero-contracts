// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Specs} from "./Base.sol";
import {Position} from "../core/Types.sol";
import {Action} from "../annotations/Action.sol";
import {Actions} from "../utils/Actions.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that fulfill an entire position.
abstract contract RealizeHook {
    /// @notice Fulfill a position and return a result satisfying its paired quote.
    /// @dev Validate the counterparty against the host account and fulfill both sides in their existing
    /// denominations before returning a position with counterparty zero.
    /// Fulfill the entire obligation or revert; no source remainder is emitted.
    /// The host chooses its internal operation order and must validate the result
    /// against the quote or revert: asset, liability, and counterparty must match,
    /// amount must meet the minimum, and debt must not exceed the maximum.
    /// The command does not validate the returned result against the quote.
    /// @param position Source position to fulfill completely.
    /// @param quote Required identifiers and counterparty, minimum amount, and maximum debt.
    /// @return Complete realized position satisfying the quote.
    function realize(Position memory position, Position memory quote) internal virtual returns (Position memory);
}

/// @notice Pass each POSITION and paired QUOTE to the realization hook.
abstract contract Realize is CommandBase, RealizeHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("realize", Specs.Position, Specs.Quote, Specs.Position, 0);
        action(id, Actions.Realize);
    }

    /// @notice Realize POSITION state blocks as their paired requested shapes.
    /// @param context Command context carrying POSITION state and one QUOTE input per position.
    /// @return POSITION blocks returned by the realization hook.
    /// @return Zero native budget credit.
    function realize(bytes calldata context) external onlyCommand returns (bytes memory, uint) {
        Execution memory exec = openCommand(context, descriptor);

        while (exec.more()) {
            Position memory position = exec.unpackPositionValue();
            Position memory quote = exec.unpackQuoteValue();
            position = realize(position, quote);
            exec.outputPosition(position);
        }

        return exec.close();
    }
}
