// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Tx} from "./Entity.sol";
import {encodeInitiate} from "./Commands/Core/Initiate.sol";
//import {encodeUtilize} from "./Commands/Core/Utilize.sol";

// input: function selector plus encoded params plus context offset. concat ctx length plus ctx

// meta: void(0), done(1), next(2), call(3)
// meta txs ??

library Io {
    uint16 internal constant DONE = 1;
    uint16 internal constant NEXT = 2;
    uint16 internal constant CALL = 3;

/*     function done() internal pure returns (bytes32, bytes memory) {
        return (DONE, "");
    } */

    function initate(
        uint account
    ) internal pure returns (bytes32, bytes memory) {
        return encodeInitiate(account);
    }

/*     function utilize(
        uint account,
        uint id,
        uint amount,
        bytes memory data
    ) internal pure returns (bytes32, bytes memory) {
        return encodeUtilize(account, id, amount, data);
    } */
}
