// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {Pipeline} from "../core/Pipeline.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

/// @title PortPipePayable
/// @notice Port that consumes CONTEXT blocks and executes each request as a step stream.
/// Each context's request bytes are passed to the shared pipeline.
abstract contract PortPipePayable is PortBase, Pipeline {
    uint internal immutable portPipePayableId = portId(this.portPipePayable.selector);

    constructor() {
        emit Port(host, portPipePayableId, "1:0", Schemas.Context, "", true);
        emit Labeled(portPipePayableId, bytes32(0), "portPipePayable");
    }

    /// @notice Execute peer-supplied contexts through the shared payable pipe.
    /// @dev All contexts share the peer call's native-value budget. Any unspent
    ///      `msg.value` remains on this host.
    /// @param data CONTEXT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portPipePayable(bytes calldata data) external payable onlyPeer returns (bytes memory) {
        (Cur memory input, , ) = Cursors.init(data, 1);
        Budget memory budget = openValue();

        while (input.i < input.len) {
            (bytes32 account, bytes calldata state, bytes calldata request) = input.unpackContext();
            pipe(account, state, request, budget);
        }

        input.complete();
        return "";
    }
}
