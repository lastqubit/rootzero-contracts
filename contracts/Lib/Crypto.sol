// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

abstract contract Crypto {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    error InvalidSignature();

    function toEthHash(bytes calldata data) public pure returns (bytes32) {
        return keccak256(data).toEthSignedMessageHash();
    }

    function isSigned(bytes32 hash, address by, bytes calldata sig) internal pure returns (bool) {
        if (hash == 0 || by == address(0) || sig.length == 0) return false;
        return hash.toEthSignedMessageHash().recover(sig) == by;
    }

    function verify(bytes32 hash, address signer, bytes calldata sig) internal pure returns (bool) {
        if (isSigned(hash, signer, sig) == false) {
            revert InvalidSignature();
        }
        return true;
    }
}
