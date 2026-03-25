// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

library ECDSA {
    uint256 internal constant MALLEABILITY_THRESHOLD =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 digest) {
        assembly ("memory-safe") {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, hash)
            digest := keccak256(0x00, 0x3c)
        }
    }

    function tryRecoverCalldata(bytes32 hash, bytes calldata signature) internal pure returns (address signer) {
        if (signature.length != 65) return address(0);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly ("memory-safe") {
            let offset := signature.offset
            r := calldataload(offset)
            s := calldataload(add(offset, 0x20))
            v := byte(0, calldataload(add(offset, 0x40)))
        }

        if (v < 27) v += 27;
        if (v != 27 && v != 28) return address(0);
        if (uint256(s) > MALLEABILITY_THRESHOLD) return address(0);

        return ecrecover(hash, v, r, s);
    }
}
