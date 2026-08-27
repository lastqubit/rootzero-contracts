// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {InvalidId, InvalidPreimage} from "./Errors.sol";

/// @title Ids
/// @notice Shared helpers for the protocol-wide 256-bit ID convention.
///
/// IDs whose first byte is zero are opaque:
///   `[0x00][bytes31 truncated hash]`
///
/// Opaque keccak preimages start with `0x01`, and the ID is derived as:
///   `0x00 || bytes31(keccak256(preimage))`
library Ids {
    /// @dev Preimage format/hash tag for keccak256-derived opaque IDs.
    uint8 constant Keccak = 0x01;

    /// @notice Return true if `id` is opaque.
    function isOpaque(bytes32 id) internal pure returns (bool) {
        return uint8(uint(id) >> 248) == 0;
    }

    /// @notice Assert that `value` is opaque and return it unchanged.
    /// @param value ID to validate.
    /// @return id The same `value` if it is opaque.
    function opaque(bytes32 value) internal pure returns (bytes32 id) {
        if (!isOpaque(value)) revert InvalidId();
        return value;
    }

    /// @notice Derive an opaque ID from a keccak preimage.
    /// @param preimage Preimage whose first byte is `0x01`.
    /// @return id `0x00 || bytes31(keccak256(preimage))`.
    function toKeccak(bytes memory preimage) internal pure returns (bytes32 id) {
        if (preimage.length == 0 || uint8(preimage[0]) != Keccak) revert InvalidPreimage();
        return bytes32(uint(keccak256(preimage)) >> 8);
    }

    /// @notice Assert that `value` matches the opaque keccak ID for `preimage`.
    /// @param value Opaque ID to validate.
    /// @param preimage Preimage whose first byte is `0x01`.
    /// @return id The same `value` if it matches.
    function matchKeccak(bytes32 value, bytes memory preimage) internal pure returns (bytes32 id) {
        if (value != toKeccak(preimage)) revert InvalidId();
        return value;
    }
}
