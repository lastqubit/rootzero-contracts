// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {Cursors, Cur, Keys} from "../Cursors.sol";

using Cursors for Cur;

abstract contract RedeemBalanceHook {
    /// @notice Override to redeem one balance claim from a peer host into local assets.
    /// @param peer Peer host node ID for this request.
    /// @param asset Asset identifier to redeem locally.
    /// @param amount Amount to redeem in the asset's native units.
    function redeemBalance(uint peer, bytes32 asset, uint amount) internal virtual;
}

/// @title PortRedeemBalance
/// @notice Port that redeems balance state from a peer host into local assets.
/// Each BALANCE block in the request calls `redeemBalance(peer, asset, amount)`.
/// Restricted to trusted peers.
abstract contract PortRedeemBalance is PortBase, RedeemBalanceHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = port("portRedeemBalance", Keys.Balance, Keys.Empty, 0, false);
    }

    /// @notice Execute the balance redemption port call.
    /// @param data BALANCE block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portRedeemBalance(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory input, ) = openInput(data, descriptor);
        uint peer = caller();

        while (input.i < input.len) {
            (bytes32 asset, uint amount) = input.unpackBalance();
            redeemBalance(peer, asset, amount);
        }
        return "";
    }
}
