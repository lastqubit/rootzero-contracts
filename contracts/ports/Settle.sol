// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PortBase } from "./Base.sol";
import { CreditAccountHook } from "../commands/Credit.sol";
import { DebitAccountHook } from "../commands/Debit.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";

using Cursors for Cur;

/// @title PortSettle
/// @notice Port that consumes peer-supplied TRANSACTION blocks through debit and credit hooks.
/// Each TRANSACTION block calls `debitAccount` for `from` and `creditAccount` for `to`.
abstract contract PortSettle is PortBase, DebitAccountHook, CreditAccountHook {
    uint internal immutable portSettleId = portId(this.portSettle.selector);

    constructor() {
        emit Port(host, portSettleId, "1:0", Schemas.Transaction, "", false);
        emit Labeled(portSettleId, bytes32(0), "portSettle");
    }

    /// @notice Execute the port-settle call.
    /// @param data TRANSACTION block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portSettle(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory state, ) = Cursors.init(data, 1);

        while (state.i < state.len) {
            (bytes32 from, bytes32 to, bytes32 asset, uint amount) = state.unpackTransaction();
            if (from != 0) debitAccount(from, asset, amount);
            if (to != 0) creditAccount(to, asset, amount);
        }

        state.complete();
        return "";
    }
}
