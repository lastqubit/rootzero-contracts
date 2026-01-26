// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Crypto} from "./Crypto.sol";
import {DeadlineNonces} from "./Nonce.sol";

// signed -> signer(20):deadline(8):sig(65)
// param -> data:eid(32):deadline(8):sig(65)
// 40 bits is plenty for deadline,

abstract contract Validator is DeadlineNonces, Crypto {
    function validate(address from, bytes calldata data, bytes calldata sig) internal pure {
        verify(keccak256(data), from, sig);
    }

    /**
     * @param from expected signer of data.
     * @param data data to be hashed and verified packed with sig at the end.
     */
    function validatePacked(address from, bytes calldata data) internal pure {
        uint sos = data.length - 65;
        verify(keccak256(data[:sos]), from, data[sos:]);
    }

    /**
     * @param data data to be hashed and verified.
     * @param signed packed context: signer(bytes20):deadline(bytes8):sig(bytes65).
     * @return address recovered signer address.
     */
    function validateRecover(bytes memory data, bytes calldata signed) internal pure returns (address) {
        address from = address(bytes20(signed));
        uint sos = signed.length - 65;
        verify(keccak256(data), from, signed[sos:]);
        return from;
    }
}
