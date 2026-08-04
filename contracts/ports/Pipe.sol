// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {Pipeline} from "../core/Pipeline.sol";
import {Specs} from "../Codec.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";
import {Budget} from "../execution/Budget.sol";

using Executions for Execution;

/// @title PortPipePayable
/// @notice Port that consumes CONTEXT blocks and executes each input as a step stream.
/// Each context's input bytes are passed to the shared pipeline.
abstract contract PortPipePayable is PortBase, Pipeline {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portPipePayable", Specs.Context, Specs.Empty, true);
    }

    /// @notice Execute peer-supplied contexts through the shared payable pipe.
    /// @dev All contexts share the peer call's native-value budget. Any unspent
    ///      `msg.value` remains on this host.
    /// @param data CONTEXT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portPipePayable(bytes calldata data) external payable onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor, 0);
        Budget memory budget = exec.takeBudget();

        while (exec.more()) {
            (bytes32 account, bytes calldata state, bytes calldata input) = exec.unpackContext(Lanes.Input);
            pipe(account, state, input, budget);
        }
        
        return "";
    }
}
