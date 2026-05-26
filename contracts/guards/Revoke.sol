// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {GuardBase} from "./Base.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
using Cursors for Cur;

/// @title Revoke
/// @notice Guardian action that quickly revokes authorization from a list of node IDs.
/// Each NODE block in the request is deauthorized on the host.
/// Only callable by active guardian addresses.
abstract contract Revoke is GuardBase {
    string private constant NAME = "revoke";

    uint internal immutable revokeId = guardId(NAME);

    constructor() {
        emit Guard(host, revokeId, NAME, Schemas.Node);
    }

    function revoke(bytes calldata request) external onlyGuardian {
        (Cur memory input, ) = cursor(request, 1);

        while (input.i < input.bound) {
            uint node = input.unpackNode();
            setNode(node, false);
        }

        input.close();
    }
}
