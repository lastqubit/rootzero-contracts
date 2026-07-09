// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {AllowanceHook} from "../commands/admin/Allowance.sol";
import {Cursors, Cur, Keys} from "../Cursors.sol";

using Cursors for Cur;

/// @title PortAllowance
/// @notice Port that lets a trusted peer host request or refresh its own allowance.
/// Each AMOUNT block in the request is scoped to the peer host and passed to the
/// shared allowance hook as a host-scoped allowance. Restricted to trusted peers.
abstract contract PortAllowance is PortBase, AllowanceHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = port("portAllowance", Keys.Amount, Keys.Empty, 0, false);
    }

    /// @notice Execute the allowance port call.
    /// @param data AMOUNT block stream requested by the trusted peer.
    /// @return Empty response bytes.
    function portAllowance(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory input, ) = openInput(data, descriptor);
        uint peer = caller();

        while (input.i < input.len) {
            (bytes32 asset, uint amount) = input.unpackAmount();
            allowance(peer, asset, amount);
        }
        return "";
    }
}
