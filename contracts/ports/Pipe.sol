// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {Pipeline} from "../core/Pipeline.sol";
import {Cursors, Cur, Keys} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

/// @title PortPipePayable
/// @notice Port that consumes CONTEXT blocks and executes each request as a step stream.
/// Each context's request bytes are passed to the shared pipeline.
abstract contract PortPipePayable is PortBase, Pipeline {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = port("portPipePayable", Keys.Context, Keys.Empty, 0, true);
    }

    /// @notice Execute peer-supplied contexts through the shared payable pipe.
    /// @dev All contexts share the peer call's native-value budget. Any unspent
    ///      `msg.value` remains on this host.
    /// @param data CONTEXT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portPipePayable(bytes calldata data) external payable onlyPeer returns (bytes memory) {
        (Cur memory input, ) = openInput(data, descriptor);
        Budget memory budget = openValue();

        while (input.i < input.len) {
            (bytes32 account, bytes calldata state, bytes calldata request) = input.unpackContext();
            pipe(account, state, request, budget);
        }
        return "";
    }
}
