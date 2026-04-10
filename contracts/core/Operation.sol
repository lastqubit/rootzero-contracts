// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AccessControl } from "./Access.sol";
import { Assets } from "../utils/Assets.sol";
import { Ids } from "../utils/Ids.sol";
import { Cur, Cursors } from "../Cursors.sol";

using Cursors for Cur;

error FailedCall(address addr, uint node, bytes4 selector, bytes err);

abstract contract OperationBase is AccessControl {
    bytes32 public immutable valueAsset = Assets.toValue();

    function cursor(bytes calldata source) internal pure returns (Cur memory cur) {
        return Cursors.open(source);
    }

    function cursor(bytes calldata source, uint g) internal pure returns (Cur memory cur, uint count) {
        cur = Cursors.open(source);
        (, count) = cur.primeRun(g);
        if (count == 0) revert Cursors.ZeroCursor();
    }

    function checkRatio(uint lc, uint lg, uint rc, uint rg) internal pure {
        if (lg == 0 || rg == 0) revert Cursors.ZeroGroup();
        if (lc == 0 || rc == 0) revert Cursors.ZeroCursor();
        if (lc % lg != 0 || rc % rg != 0) revert Cursors.BadRatio();
        if (lc / lg != rc / rg) revert Cursors.BadRatio();
    }

    function callTo(uint node, uint value, bytes memory data) internal returns (bytes memory out) {
        bool success;
        address addr = Ids.nodeAddr(ensureTrusted(node));
        (success, out) = payable(addr).call{value: value}(data);
        if (!success) {
            revert FailedCall(addr, node, bytes4(data), out);
        }
    }
}




