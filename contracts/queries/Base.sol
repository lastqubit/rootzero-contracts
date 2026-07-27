// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EndpointBase } from "../core/Endpoint.sol";
import { Specs } from "../codec/Specs.sol";
import { Nodes } from "../utils/Nodes.sol";
import { Selectors } from "../utils/Selectors.sol";

/// @title QueryBase
/// @notice Abstract base for rootzero query contracts.
/// Queries are view-only entry points that consume a block-stream request and
/// return a block-stream response.
abstract contract QueryBase is EndpointBase {

    /// @notice Publish query metadata and a default label.
    /// @param name Default human-readable query label and selector name.
    /// @param input Input block specification.
    /// @param output Output block specification.
    /// @param selector Query ABI selector, or zero to derive it from `name`.
    /// @return id Query node ID.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function query(
        string memory name,
        uint input,
        uint output,
        bytes4 selector
    ) internal returns (uint id, uint descriptor) {
        selector = selector == bytes4(0) ? Selectors.query(name) : selector;
        id = Nodes.toQuery(selector, address(this));
        descriptor = endpoint(id, name, Specs.Empty, input, output, false, false);
    }
}
