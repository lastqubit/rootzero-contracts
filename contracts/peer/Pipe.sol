// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Pipeline} from "../core/Pipeline.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

/// @title PeerPipePayable
/// @notice Peer that consumes RELAY blocks and executes each context request as a STEP stream.
/// Each RELAY block carries a value budget plus a CONTEXT block; the relay target is ignored
/// and the nested context request is passed to the shared pipeline as the step stream.
abstract contract PeerPipePayable is PeerBase, Pipeline {
    string private constant NAME = "peerPipePayable";
    uint internal immutable peerPipePayableId = peerId(NAME);

    constructor() {
        emit Peer(host, peerPipePayableId, NAME, "1:0", Schemas.Relay, "", true);
    }

    /// @notice Execute peer-supplied relays through the shared payable pipe.
    /// @dev Each relay receives its own explicit value sub-budget. Any top-level
    ///      `msg.value` not assigned to a relay remains on this host.
    function peerPipePayable(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        (Cur memory input, ) = cursor(request, 1);
        Budget memory budget = valueBudget();

        while (input.i < input.bound) {
            (, uint value, bytes32 account, bytes calldata state, bytes calldata steps) = input.unpackRelay();
            pipe(account, state, steps, allocateValue(budget, value));
        }

        input.close();
        return "";
    }
}
