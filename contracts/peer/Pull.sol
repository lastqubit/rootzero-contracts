// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Data, DataRef, ROUTE_KEY} from "../Blocks.sol";
using Data for DataRef;

string constant NAME = "peerPull";

abstract contract PeerPull is PeerBase {
    uint internal immutable peerPullId = peerId(NAME);

    constructor(string memory route) {
        emit Peer(host, NAME, route, peerPullId);
    }

    function peerPull(DataRef memory rawRoute) internal virtual;

    function peerPull(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        uint q = 0;
        while (q < request.length) {
            (DataRef memory ref, uint next) = Data.from(request, q);
            if (ref.key != ROUTE_KEY) break;
            peerPull(ref);
            q = next;
        }

        return response("", 0, q);
    }
}
