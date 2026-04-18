// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AccessControl } from "./Access.sol";
import { Assets } from "../utils/Assets.sol";
import { Ids } from "../utils/Ids.sol";
import { Cur, Cursors } from "../Cursors.sol";

using Cursors for Cur;

/// @dev Emitted when a trusted inter-node call fails.
/// @param addr Contract address that was called.
/// @param node Node ID of the callee.
/// @param selector 4-byte selector of the called function.
/// @param err Revert data returned by the failed call.
error FailedCall(address addr, uint node, bytes4 selector, bytes err);

/// @title OperationBase
/// @notice Shared base for command and peer contracts.
/// Provides convenience wrappers for cursor construction, quotient validation,
/// and trusted inter-node calls. Inherits access control from `AccessControl`.
abstract contract OperationBase is AccessControl {
    /// @dev Asset ID for the native chain value (ETH), bound to the current chain at deployment.
    bytes32 public immutable valueAsset = Assets.toValue();

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
    /// Equivalent to `open(source)` followed by `primeRun(group)` and `checkQuotient(quotient, expectedQuotient)`.
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

    /// @notice Assert that two normalized group quotients are equal.
    /// Reverts with `Cursors.BadRatio` when `lq != rq`.
    /// @param lq Left-hand quotient.
    /// @param rq Right-hand quotient.
    function checkQuotient(uint lq, uint rq) internal pure {
        if (lq != rq) revert Cursors.BadRatio();
    }

    /// @notice Make a trusted call to another node in the network.
    /// Looks up the node's contract address via `ensureTrusted` + `Ids.nodeAddr`,
    /// then issues a low-level call forwarding `value` ETH and `data`.
    /// Reverts with `FailedCall` if the call is unsuccessful.
    /// @param node Node ID of the callee (must be in the authorized set).
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful call.
    function callTo(uint node, uint value, bytes memory data) internal returns (bytes memory out) {
        bool success;
        address addr = Ids.nodeAddr(ensureTrusted(node));
        (success, out) = payable(addr).call{value: value}(data);
        if (!success) {
            revert FailedCall(addr, node, bytes4(data), out);
        }
    }

    /// @notice Make a trusted static call to another node in the network.
    /// Looks up the node's contract address via `ensureTrusted` + `Ids.nodeAddr`,
    /// then issues a low-level `staticcall` with `data`.
    /// Reverts with `FailedCall` if the call is unsuccessful.
    /// @param node Node ID of the callee (must be in the authorized set).
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful static call.
    function staticcallTo(uint node, bytes memory data) internal view returns (bytes memory out) {
        bool success;
        address addr = Ids.nodeAddr(ensureTrusted(node));
        (success, out) = addr.staticcall(data);
        if (!success) {
            revert FailedCall(addr, node, bytes4(data), out);
        }
    }
}
