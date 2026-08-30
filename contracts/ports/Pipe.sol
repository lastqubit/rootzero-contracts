// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {Flags} from "../utils/Flags.sol";
import {PipeHook} from "../core/Pipeline.sol";
import {Specs} from "../Codec.sol";
import {Execution, Executions} from "../execution/Execution.sol";

using Executions for Execution;

/// @title PipePayablePort
/// @notice Port that consumes CONTEXT blocks and executes each input as a step stream.
/// Each context's input bytes are passed to the shared pipeline.
abstract contract PipePayablePort is PortBase, PipeHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portPipePayable", Specs.Context, Specs.Empty, Flags.Funded);
    }

    /// @notice Execute peer-supplied contexts through the shared payable pipe.
    /// @dev All contexts share the peer call's native-value budget. Any unspent
    ///      `msg.value` remains on this host.
    /// @param data CONTEXT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portPipePayable(bytes calldata data) external payable onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor);
        uint budget = exec.drainBudget();

        while (exec.more()) {
            (bytes32 account, bytes calldata state, bytes calldata input) = exec.unpackContext();
            budget = pipe(account, state, input, budget);
        }
        
        return "";
    }
}
