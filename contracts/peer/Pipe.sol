// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {PipePayableCore} from "../commands/Pipe.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

/// @title PeerPipePayable
/// @notice Peer that consumes CONTEXT blocks and executes each context request as a STEP stream.
/// Each CONTEXT block carries an account, state, and request; the request is passed to the
/// shared payable pipe core as the step stream.
abstract contract PeerPipePayable is PeerBase, PipePayableCore {
    string private constant NAME = "peerPipePayable";
    uint internal immutable peerPipePayableId = peerId(NAME);

    constructor() {
        emit Peer(host, peerPipePayableId, NAME, "1:0", Schemas.Context, "", true);
    }

    /// @notice Execute peer-supplied contexts through the shared payable pipe.
    function peerPipePayable(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        (Cur memory input, ) = cursor(request, 1);
        Budget memory budget = valueBudget();

        while (input.i < input.bound) {
            (bytes32 account, bytes calldata state, bytes calldata steps) = input.unpackContext();
            pipe(account, state, steps, budget);
        }

        input.close();
        return "";
    }
}
