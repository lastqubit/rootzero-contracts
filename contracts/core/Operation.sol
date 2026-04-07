// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AccessControl } from "./Access.sol";
import { Assets } from "../utils/Assets.sol";
import { Ids } from "../utils/Ids.sol";

error NoOperation();
error FailedCall(address addr, uint node, bytes4 selector, bytes err);

abstract contract OperationBase is AccessControl {
    bytes32 public immutable valueAsset = Assets.toValue();

    function done(uint start, uint end) internal pure returns (bytes memory) {
        if (end <= start) revert NoOperation();
        return "";
    }

    function done(bytes memory state, uint start, uint end) internal pure returns (bytes memory) {
        if (end <= start) revert NoOperation();
        return state;
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



