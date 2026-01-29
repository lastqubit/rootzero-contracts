// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

abstract contract Nonces {
    mapping(address account => mapping(uint192 key => uint64)) private nonces;

    error BadNonce(address account);

    function toKey(uint keyNonce) public pure returns (uint192) {
        return uint192(keyNonce >> 64);
    }

    function toKeyNonce(uint192 key, uint64 nonce) public pure returns (uint) {
        return (uint(key) << 64) | nonce;
    }

    function getNonce(address account, uint192 key) public view returns (uint) {
        return nonces[account][key];
    }

    function useNonce(address account, uint192 key) internal returns (uint64) {
        return nonces[account][key]++;
    }

    function useNonce(address account, uint192 key, uint64 nonce) internal {
        if (nonce != nonces[account][key]++) {
            revert BadNonce(account);
        }
    }
}