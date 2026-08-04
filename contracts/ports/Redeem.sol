// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {Specs} from "../Codec.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that redeem balances received through a port.
abstract contract RedeemBalanceHook {
    /// @notice Override to redeem one balance claim from a peer host into local assets.
    /// @param peer Peer host node ID for this input.
    /// @param asset Asset identifier to redeem locally.
    /// @param amount Amount to redeem in the asset's native units.
    function redeemBalance(uint peer, bytes32 asset, uint amount) internal virtual;
}

/// @title PortRedeemBalance
/// @notice Port that redeems balance state from a peer host into local assets.
/// Each BALANCE block in the input calls `redeemBalance(peer, asset, amount)`.
/// Restricted to trusted peers.
abstract contract PortRedeemBalance is PortBase, RedeemBalanceHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portRedeemBalance", Specs.Balance, Specs.Empty, false);
    }

    /// @notice Execute the balance redemption port call.
    /// @param data BALANCE block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portRedeemBalance(bytes calldata data) external onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor, 0);
        uint peer = caller();

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackBalance(Lanes.Input);
            redeemBalance(peer, asset, amount);
        }
        
        return "";
    }
}
