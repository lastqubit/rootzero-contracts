// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Utilize} from "./Core/Utilize.sol";

string constant REQ = "swap(uint use, uint accept)";

struct SwapRequest {
    uint use;
    uint accept;
    uint rate;
}

struct SwapFactor {
    uint use;
    uint accept;
    uint rate;
}

abstract contract Swap is Utilize(REQ) {
    function getSwapRequest(
        bytes calldata ctx
    ) internal view returns (SwapRequest memory) {
        return abi.decode(ctx, (SwapRequest)); ///
    }
}
