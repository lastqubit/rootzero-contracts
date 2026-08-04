// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EndpointBase } from "../core/Endpoint.sol";
import { Specs } from "../codec/Specs.sol";
import { Nodes } from "../utils/Nodes.sol";
import { Selectors } from "../utils/Selectors.sol";

/// @title QueryBase
/// @notice Abstract base for rootzero query contracts.
/// Queries are view-only entry points that consume a block-stream input and
/// return a block-stream response.
abstract contract QueryBase is EndpointBase {

    /// @notice Publish query metadata and a default label.
    /// @param name Query entrypoint name and default label. It must exactly
    /// match the Solidity query function name used by the canonical ABI.
    /// @param input Input block specification.
    /// @param output Output block specification.
    /// @return id Query node ID.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function query(
        string memory name,
        uint input,
        uint output
    ) internal returns (uint id, uint descriptor) {
        id = Nodes.toQuery(Selectors.query(name), address(this));
        descriptor = endpoint(id, name, Specs.Empty, input, output, 0, 0);
    }
}
