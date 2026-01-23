// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Crypto} from "./Crypto.sol";
import {DeadlineNonces} from "./Nonce.sol";

// data:eid(32):deadline(8):sig(65)
// 40 bits is plenty for deadline,

abstract contract Validator is DeadlineNonces, Crypto {
    function validate(address from, bytes calldata data, bytes calldata sig) internal pure {
        verify(toHash(data), from, sig);
    }
}
