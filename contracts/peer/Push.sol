// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Data, DataRef, ROUTE_KEY} from "../Blocks.sol";
using Data for DataRef;

string constant NAME = "peerPush";

abstract contract PeerPush is PeerBase {
    uint internal immutable peerPushId = peerId(NAME);

    constructor(string memory route) {
        emit Peer(host, NAME, route, peerPushId);
    }

    function peerPush(DataRef memory rawRoute) internal virtual;

    function peerPush(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        uint q = 0;
        while (q < request.length) {
            (DataRef memory ref, uint next) = Data.from(request, q);
            if (ref.key != ROUTE_KEY) break;
            peerPush(ref);
            q = next;
        }

        return response("", 0, q);
    }
}
