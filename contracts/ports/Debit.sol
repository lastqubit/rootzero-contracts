// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PortBase } from "./Base.sol";
import { DebitAccountHook } from "../commands/Debit.sol";
import { Cursors, Cur, Keys } from "../Cursors.sol";

using Cursors for Cur;

/// @title PortDebitAccount
/// @notice Port that lets a trusted peer debit supplied accounts directly.
/// Each ACCOUNT_AMOUNT block calls `debitAccount` for its account.
abstract contract PortDebitAccount is PortBase, DebitAccountHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = port("portDebitAccount", Keys.AccountAmount, Keys.Empty, 0, false);
    }

    /// @notice Execute the port-debit call.
    /// @param data ACCOUNT_AMOUNT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portDebitAccount(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory input, ) = openInput(data, descriptor);

        while (input.i < input.len) {
            (bytes32 account, bytes32 asset, uint amount) = input.unpackAccountAmount();
            debitAccount(account, asset, amount);
        }
        return "";
    }
}
