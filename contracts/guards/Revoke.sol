// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {GuardBase} from "./Base.sol";
import {Cursors, Cur, Keys} from "../Cursors.sol";
using Cursors for Cur;

/// @title Revoke
/// @notice Guardian action that quickly revokes authorization from a list of node IDs.
/// Each NODE block in the request is deauthorized on the host.
/// Only callable by active guardian addresses.
abstract contract Revoke is GuardBase {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = guard("revoke", Keys.Node, 0);
    }

    function revoke(bytes calldata request) external onlyGuardian {
        (Cur memory input, ) = openInput(request, descriptor);

        while (input.i < input.len) {
            uint node = input.unpackNode();
            setNode(node, false);
        }

    }
}
