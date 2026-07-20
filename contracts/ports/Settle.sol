// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PortBase } from "./Base.sol";
import { Settlement } from "../core/Settlement.sol";
import { Cursors, Cur, Keys } from "../Cursors.sol";

using Cursors for Cur;

/// @title PortSettle
/// @notice Port that consumes peer-supplied TRANSACTION blocks through debit and credit hooks.
/// Each TRANSACTION block calls `debitAccount` for `from` and `creditAccount` for `to`.
abstract contract PortSettle is PortBase, Settlement {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = port("portSettle", Keys.Transaction, Keys.Empty, 0, false);
    }

    /// @notice Execute the port-settle call.
    /// @param data TRANSACTION block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portSettle(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory input, ) = openInput(data, descriptor);

        while (input.i < input.len) {
            (bytes32 from, bytes32 to, bytes32 asset, uint amount) = input.unpackTransaction();
            settle(from, to, asset, amount);
        }
        return "";
    }
}
