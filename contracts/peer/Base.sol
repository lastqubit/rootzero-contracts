// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {AccessControl} from "../core/Access.sol";
import {PeerEvent} from "../events/Peer.sol";
import {toPeerId, toPeerSelector} from "../utils/Ids.sol";

error NoResponse();

abstract contract PeerBase is AccessControl, PeerEvent {

    modifier onlyPeer() {
        enforceCaller(msg.sender);
        _;
    }

    function peerId(string memory name) internal view returns (uint) {
        return toPeerId(toPeerSelector(name), address(this));
    }

    function response(bytes memory state, uint start, uint end) internal pure returns (bytes memory) {
        if (end <= start) revert NoResponse();
        return state;
    }
}
