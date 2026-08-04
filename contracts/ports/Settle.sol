// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {Settlement} from "../core/Settlement.sol";
import {Specs} from "../Codec.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";

using Executions for Execution;

/// @title PortSettle
/// @notice Port that consumes peer-supplied TRANSACTION blocks through debit and credit hooks.
/// Each TRANSACTION block calls `debitAccount` for `from` and `creditAccount` for `to`.
abstract contract PortSettle is PortBase, Settlement {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portSettle", Specs.Transaction, Specs.Empty, false);
    }

    /// @notice Execute the port-settle call.
    /// @param data TRANSACTION block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portSettle(bytes calldata data) external onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor, 0);

        while (exec.more()) {
            (bytes32 from, bytes32 to, bytes32 asset, uint amount) = exec.unpackTransaction(Lanes.Input);
            settle(from, to, asset, amount);
        }
        
        return "";
    }
}
