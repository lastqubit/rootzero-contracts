// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Runtime } from "../core/Runtime.sol";
import { LabeledEvent } from "../events/Labeled.sol";
import { QueryEvent } from "../events/Query.sol";
import { Nodes } from "../utils/Nodes.sol";

/// @title QueryBase
/// @notice Abstract base for rootzero query contracts.
/// Queries are view-only entry points that consume a block-stream request and
/// return a block-stream response.
abstract contract QueryBase is Runtime, QueryEvent, LabeledEvent {

    /// @notice Derive the deterministic node ID for a query selector on this contract.
    /// The ID encodes the ABI selector and `address(this)`, making it unique
    /// per (function selector, contract address) pair.
    /// @param selector Query entrypoint selector.
    /// @return Query node ID.
    function queryId(bytes4 selector) internal view returns (uint) {
        return Nodes.toQuery(selector, address(this));
    }
}
