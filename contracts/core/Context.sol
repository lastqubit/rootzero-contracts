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
    /// @return groups Number of block groups in the run (`prime block count / group`).
    function cursor(bytes calldata source, uint group) internal pure returns (Cur memory cur, uint groups) {
        cur = Cursors.open(source);
        (, groups) = cur.primeRun(group);
    }

    /// @notice Open a cursor, prime it, and assert that its group count matches `expectedGroups`.
    /// Equivalent to `open(source)` followed by `primeRun(group)` and a direct group-count equality check.
    /// Reverts with `Cursors.BadRatio` when the group count does not match.
    /// @param source Calldata slice to parse.
    /// @param group Expected block group size (e.g. 1 for single, 2 for paired).
    /// @param expectedGroups Required number of groups in the first run.
    /// @return cur Cursor with `bound` set to the end of the first run.
    function cursor(bytes calldata source, uint group, uint expectedGroups) internal pure returns (Cur memory cur) {
        cur = Cursors.open(source);
        (, uint groups) = cur.primeRun(group);
        if (groups != expectedGroups) revert Cursors.BadRatio();
    }
}
