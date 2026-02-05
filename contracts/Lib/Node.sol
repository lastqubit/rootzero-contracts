// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {AccessControl} from "./Access.sol";
import {AccessEvent} from "./Events/Node/Access.sol";
import {QueryEvent} from "./Events/Node/Query.sol";
import {StepEvent} from "./Events/Node/Step.sol";
import {EntryEvent} from "./Events/Node/Entry.sol";
import {toValueId, toNodeId, toEndpointId} from "./Utils.sol";

abstract contract Node is AccessControl, AccessEvent, QueryEvent, StepEvent, EntryEvent {
    uint public immutable nodeId = toNodeId(address(this));
    uint public immutable valueId = toValueId();

    error FailedCall(address addr, bytes4 selector, bytes err);

    function toEid(bytes4 selector) internal view returns (uint) {
        return toEndpointId(address(this), selector);
    }

    function access(address addr, bool allow) internal {
        authorized[addr] = allow;
        emit Access(nodeId, addr, allow);
    }

    function callAddr(address addr, uint value, bytes memory data) internal returns (bytes memory out) {
        bool success;
        (success, out) = payable(ensureTrusted(addr)).call{value: value}(data);
        if (success == false) {
            revert FailedCall(addr, bytes4(data), out);
        }
    }
}
