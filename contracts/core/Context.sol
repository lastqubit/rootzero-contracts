// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors} from "../Cursors.sol";
import {Assets} from "../utils/Assets.sol";
import {Ids} from "../utils/Ids.sol";

using Cursors for Cur;

/// @title RootZeroContext
/// @notice Shared rootzero contract context for host identity, native value identity, and block-stream cursors.
abstract contract RootZeroContext {
    /// @dev This contract's host node ID, set to `Ids.toHost(address(this))` at construction.
    uint public immutable host = Ids.toHost(address(this));
    /// @dev Asset ID for the native chain value (ETH), bound to the current chain at deployment.
    bytes32 internal immutable valueAsset = Assets.toValue();

    /// @notice Open a cursor over a calldata block stream.
    /// @param source Calldata slice to parse.
    /// @return cur Cursor positioned at the beginning of `source`.
    function cursor(bytes calldata source) internal pure returns (Cur memory cur) {
        return Cursors.open(source);
    }

    /// @notice Open a cursor and prime it for a grouped iteration pass in one call.
    /// Equivalent to `open(source)` followed by `primeRun(group)`.
    /// @param source Calldata slice to parse.
    /// @param group Expected block group size (e.g. 1 for single, 2 for paired).
    /// @return cur Cursor with `bound` set to the end of the first run.
    /// @return count Total number of blocks in the run (a multiple of `group`).
    /// @return quotient Number of groups in the run (`count / group`).
    function cursor(bytes calldata source, uint group) internal pure returns (Cur memory cur, uint count, uint quotient) {
        cur = Cursors.open(source);
        (, count, quotient) = cur.primeRun(group);
    }

    /// @notice Open a cursor, prime it, and assert that its normalized quotient matches `expectedQuotient`.
    /// Equivalent to `open(source)` followed by `primeRun(group)` and a direct quotient equality check.
    /// Reverts with `Cursors.BadRatio` when the quotient does not match.
    /// @param source Calldata slice to parse.
    /// @param group Expected block group size (e.g. 1 for single, 2 for paired).
    /// @param expectedQuotient Required number of groups in the first run.
    /// @return cur Cursor with `bound` set to the end of the first run.
    function cursor(bytes calldata source, uint group, uint expectedQuotient) internal pure returns (Cur memory cur) {
        cur = Cursors.open(source);
        (, , uint quotient) = cur.primeRun(group);
        if (quotient != expectedQuotient) revert Cursors.BadRatio();
    }
}
