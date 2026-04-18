// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { OperationBase } from "../core/Operation.sol";
import { QueryEvent } from "../events/Query.sol";
import { Ids, Selectors } from "../utils/Ids.sol";

/// @notice ABI-encode a query call from a target query ID and request block stream.
/// @dev Derives the function selector from `target` via `Ids.querySelector(target)`.
/// Reverts if `target` is not a valid query ID.
/// @param target Destination query node ID embedding the target selector.
/// @param request Input block stream for the query invocation.
/// @return ABI-encoded calldata for the query entry point.
function encodeQueryCall(uint target, bytes calldata request) pure returns (bytes memory) {
    bytes4 selector = Ids.querySelector(target);
    return abi.encodeWithSelector(selector, request);
}

/// @title QueryBase
/// @notice Abstract base for rootzero query contracts.
/// Queries are view-only entry points that consume a block-stream request and
/// return a block-stream response.
abstract contract QueryBase is OperationBase, QueryEvent {
    /// @notice Derive the deterministic node ID for a named query on this contract.
    /// The ID encodes the ABI selector of `name(bytes)` and `address(this)`,
    /// making it unique per (function name, contract address) pair.
    /// @param name Query function name (without argument list).
    /// @return Query node ID.
    function queryId(string memory name) internal view returns (uint) {
        return Ids.toQuery(Selectors.query(name), address(this));
    }
}
