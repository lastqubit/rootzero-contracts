// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Crypto} from "./Crypto.sol";
import {Nonces} from "./Nonce.sol";

// param -> data:eid(32):deadline(8):sig(65) // signer should be part of data
// 40 bits is plenty for deadline,

abstract contract Validator is Nonces, Crypto {
    /**
     * @param signer signer of data.
     * @param hash keccak256 of data.
     * @param sig signature.
     */
    function validate(address signer, bytes32 hash, bytes calldata sig) internal pure {
        verify(hash, signer, sig);
    }

    /**
     * @param signer signer of data.
     * @param data packed (bytes data to keccak256, bytes65 sig).
     */
    function validatePacked(address signer, bytes calldata data) internal pure {
        uint sos = data.length - 65;
        verify(keccak256(data[:sos]), signer, data[sos:]);
    }

    /**
     * @param hash keccak256 of data.
     * @param signed packed (bytes20 signer, bytes65 sig).
     * @return address recovered signer address.
     */
    function validateRecover(bytes32 hash, bytes calldata signed) internal pure returns (address) {
        address signer = address(bytes20(signed));
        verify(hash, signer, signed[20:]);
        return signer;
    }
}
