// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Transfer} from "./Core/Setup/Transfer.sol";

string constant REQ = "swish(uint to, uint use, uint min, uint max, uint fee)";

struct SwishRequest {
    uint to;
    uint use;
    uint min;
    uint max;
    uint fee;
}

abstract contract DebitFrom is Transfer(REQ) {
    function toSwishRequest(
        bytes calldata step
    ) public pure returns (SwishRequest memory) {
        return abi.decode(step[64:], (SwishRequest));
    }

    function swish(
        uint from,
        uint to,
        uint id,
        uint min,
        uint max,
        uint fee
    ) internal virtual returns (uint) {}

    function swish(
        uint from,
        bytes calldata step
    ) internal returns (bytes4, bytes memory) {
        SwishRequest memory q = toSwishRequest(step);
        uint amount = swish(from, q.to, q.use, q.min, q.max, q.fee);
        //activity(from, q.use, amount, "swish", "");
        return done();
    }

    function transfer(
        uint from,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes4, bytes memory) {
        return swish(from, step);
    }
}
