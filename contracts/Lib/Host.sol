// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {AccessControl} from "./Access.sol";
import {EndpointEvent} from "./Events/Node/Endpoint.sol";
import {toValueId, toEndpointId} from "./Utils.sol";

abstract contract Host is AccessControl, EndpointEvent {
    uint public immutable valueId = toValueId();

    error FailedCall(address addr, bytes4 selector, bytes err);
    error UnexpectedStage();

    function toEid(bytes4 selector) internal view returns (uint) {
        return toEndpointId(address(this), selector);
    }

    function ensureValidStage(uint eid, bytes calldata step) internal pure {
        if (eid != uint(bytes32(step))) {
            revert UnexpectedStage();
        }
    }

    function callTo(address addr, uint value, bytes memory data) internal returns (bytes memory out) {
        bool success;
        (success, out) = payable(ensureTrusted(addr)).call{value: value}(data);
        if (success == false) {
            revert FailedCall(addr, bytes4(data), out);
        }
    }
}

/* abstract contract CallTo is AccessControl {
    error FailedCall(bytes4 selector, address addr, uint size);

    // @dev no checks, use callTo instead.
    function callTo(
        address addr,
        uint value,
        bytes memory data
    ) internal returns (bytes memory) {
        (bool s, bytes memory out) = payable(addr).call{value: value}(data);
        if (s == false) {
            revert FailedCall(bytes4(data), addr, data.length);
        }
        return out;
    }

    function callTo(
        address addr,
        uint value,
        Value memory total,
        bytes memory data
    ) internal returns (bytes memory) {
        return callTo(ensureTrusted(addr), useValue(total, value), data);
    }
}
 */
