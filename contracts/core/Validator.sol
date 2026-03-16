// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {ECDSA} from "../utils/ECDSA.sol";

abstract contract Validator {
    using ECDSA for bytes32;

    error InvalidProof();
    error InvalidSigner();
    error NonceUsed();

    mapping(address account => mapping(uint192 key => uint64)) internal nonces;

    function recover(bytes32 hash, bytes calldata sig) private pure returns (address) {
        return hash.toEthSignedMessageHash().tryRecoverCalldata(sig);
    }

    // @dev proof is (bytes20 signer, bytes65 sig)
    function verify(bytes32 hash, uint192 nonce, bytes calldata proof) internal returns (address) {
        if (proof.length != 85) revert InvalidProof();

        address account = address(bytes20(proof[0:20]));
        address signer = recover(hash, proof[20:]);

        if (account == address(0) || signer != account) revert InvalidSigner();
        if (nonces[account][nonce]++ != 0) revert NonceUsed();

        return account;
    }
}
