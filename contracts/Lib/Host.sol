// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Id} from "./Utils/Id.sol";
import {AccessControl} from "./Access.sol";
import {EndpointEvent} from "./Events/Node/Endpoint.sol";

abstract contract Host is AccessControl, EndpointEvent {
    uint public immutable valueId = Id.value();

    error UnexpectedStage();
    // add error bytes??
    error FailedCall(bytes4 selector, address addr, uint size);

    function toEid(bool entry, bytes4 selector) internal view returns (uint) {
        return Id.endpoint(address(this), selector);
    }

    function toEid(bytes4 selector) internal view returns (uint) {
        return Id.endpoint(address(this), selector);
    }

    function ensureValidStage(uint eid, bytes calldata step) internal pure {
        if (eid != uint(bytes32(step))) {
            revert UnexpectedStage();
        }
    }

    // add ensureTrusted ?? transfer can only be called to trusted addr??
    function _call(address addr, uint value, bytes memory data) internal returns (bytes memory) {
        (bool s, bytes memory out) = payable(addr).call{value: value}(data);
        if (s == false) {
            revert FailedCall(bytes4(data), addr, data.length);
        }
        return out;
    }
}

/* abstract contract CallTo is AccessControl {
    error FailedCall(bytes4 selector, address addr, uint size);

    // @dev no checks, use callTo instead.
    function _call(
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
        return _call(ensureTrusted(addr), useValue(total, value), data);
    }
}
 */
