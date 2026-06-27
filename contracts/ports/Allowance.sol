// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {AllowanceHook} from "../commands/admin/Allowance.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

using Cursors for Cur;

interface IPortAllowance {
    function portAllowance(bytes calldata data) external returns (bytes memory);
}

/// @title PortAllowance
/// @notice Port that lets a trusted peer host request or refresh its own allowance.
/// Each AMOUNT block in the request is scoped to the peer host and passed to the
/// shared allowance hook as a host-scoped allowance. Restricted to trusted peers.
abstract contract PortAllowance is PortBase, AllowanceHook, IPortAllowance {
    uint internal immutable portAllowanceId = portId(this.portAllowance.selector);

    constructor() {
        emit Port(host, portAllowanceId, "1:0", Schemas.Amount, "", false);
        emit Labeled(portAllowanceId, bytes32(0), "portAllowance");
    }

    /// @notice Execute the allowance port call.
    /// @param data AMOUNT block stream requested by the trusted peer.
    /// @return Empty response bytes.
    function portAllowance(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory amounts, , ) = Cursors.init(data, 1);
        uint peer = caller();

        while (amounts.i < amounts.len) {
            (bytes32 asset, uint amount) = amounts.unpackAmount();
            allowance(peer, asset, amount);
        }

        amounts.complete();
        return "";
    }
}
