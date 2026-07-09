// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EndpointBase } from "../core/Endpoint.sol";
import { Nodes } from "../utils/Nodes.sol";

/// @title QueryBase
/// @notice Abstract base for rootzero query contracts.
/// Queries are view-only entry points that consume a block-stream request and
/// return a block-stream response.
abstract contract QueryBase is EndpointBase {

    /// @notice Publish query metadata and a default label.
    function query(
        string memory name,
        bytes9 input,
        bytes9 output,
        bytes4 selector
    ) internal returns (uint id, bytes32 descriptor) {
        if (selector == bytes4(0)) {
            selector = bytes4(keccak256(bytes(string.concat(name, "(bytes)"))));
        }
        id = Nodes.toQuery(selector, address(this));
        descriptor = endpoint(bytes9(0), input, output, false, false);
        defineEndpoint(host, id, descriptor, name);
    }
}
