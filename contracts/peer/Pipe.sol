// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {PipePayableCore} from "../commands/Pipe.sol";
import {Cursors, Cur, Schemas, Writer, Writers} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;
using Writers for Writer;

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

/// @title PeerStagePayable
/// @notice Peer that consumes CONTEXT blocks and executes each context request as a STEP stream stage.
/// Each output CONTEXT block carries the original account, the final threaded state, and an empty request.
abstract contract PeerStagePayable is PeerBase, PipePayableCore {
    string private constant NAME = "peerStagePayable";
    uint internal immutable peerStagePayableId = peerId(NAME);

    constructor() {
        emit Peer(host, peerStagePayableId, NAME, "1:1", Schemas.Context, Schemas.Context, true);
    }

    /// @notice Execute peer-supplied contexts as stages and return one CONTEXT block per input context.
    function peerStagePayable(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        (Cur memory input, uint groups) = cursor(request, 1);
        Budget memory budget = valueBudget();
        Writer memory response = Writers.allocContexts(groups);

        while (input.i < input.bound) {
            (bytes32 account, bytes calldata state, bytes calldata steps) = input.unpackContext();
            bytes memory out = stage(account, state, steps, budget);
            response.appendContext(account, out, new bytes(0));
        }

        input.close();
        return response.finish();
    }
}
