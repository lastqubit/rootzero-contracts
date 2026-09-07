// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Position} from "../core/Types.sol";
import {AmountOutOfRange, UnexpectedValue} from "./Errors.sol";

/// @notice Validation helpers for decoded positions and quotes.
library Positions {
    /// @notice Assert that a position satisfies a decoded quote.
    /// @dev Reverts with `UnexpectedValue` for an identifier or counterparty mismatch,
    /// or `AmountOutOfRange` for an amount below the minimum or debt above the maximum.
    /// @param position Resulting position to validate.
    /// @param quote Exact identifiers and counterparty, minimum amount, and maximum debt.
    function requireQuoted(Position memory position, Position memory quote) internal pure {
        if (position.asset != quote.asset || position.liability != quote.liability || position.counterparty != quote.counterparty) revert UnexpectedValue();
        if (position.amount < quote.amount || position.debt > quote.debt) revert AmountOutOfRange();
    }
}
