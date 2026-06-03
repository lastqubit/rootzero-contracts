// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Pipeline} from "../core/Pipeline.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

/// @title PeerPipePayable
/// @notice Peer that consumes PIPE blocks and executes each context step stream.
/// Each PIPE block carries a value budget plus a CONTEXT block; the nested
/// context steps are passed to the shared pipeline as the step stream.
abstract contract PeerPipePayable is PeerBase, Pipeline {
    string private constant NAME = "peerPipePayable";
    uint internal immutable peerPipePayableId = peerId(NAME);

    constructor() {
        emit Peer(host, peerPipePayableId, NAME, "1:0", Schemas.Pipe, "", true);
    }

    /// @notice Execute peer-supplied pipes through the shared payable pipe.
    /// @dev Each pipe receives its own explicit value sub-budget. Any top-level
    ///      `msg.value` not assigned to a pipe remains on this host.
    /// @param request PIPE block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerPipePayable(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        (Cur memory input, ) = Cursors.first(request, 1);
        Budget memory budget = valueBudget();

        while (input.i < input.len) {
            (uint value, bytes32 account, bytes calldata state, bytes calldata steps) = input.unpackPipe();
            pipe(account, state, steps, allocateValue(budget, value));
        }

        input.complete();
        return "";
    }
}
