// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {CollectEvent} from "./Events/Account/Collect.sol";
import {calcBps} from "./Utils.sol";
import {deductFrom} from "./Utils.sol";

abstract contract Fees is CollectEvent {
    uint public immutable collector;

    function burnFee(
        uint fee,
        uint id,
        uint disposable
    ) internal virtual returns (uint) {
        if (fee == 0) return disposable;
        uint out = deductFrom(fee, disposable);
        //emit Collect(collector, id, fee);
        return out;
    }

    function burnFeeBps(
        uint16 bps,
        uint id,
        uint disposable
    ) internal returns (uint) {
        return burnFee(calcBps(disposable, bps), id, disposable);
    }
}
