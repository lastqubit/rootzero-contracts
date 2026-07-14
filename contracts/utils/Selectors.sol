// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title Selectors
/// @notice Canonical ABI selector derivation for rootzero endpoint types.
library Selectors {
    function command(string memory name) internal pure returns (bytes4) {
        return derive(name, "((bytes32,bytes,bytes))");
    }

    function port(string memory name) internal pure returns (bytes4) {
        return direct(name);
    }

    function query(string memory name) internal pure returns (bytes4) {
        return direct(name);
    }

    function guard(string memory name) internal pure returns (bytes4) {
        return direct(name);
    }

    function direct(string memory name) private pure returns (bytes4) {
        return derive(name, "(bytes)");
    }

    function derive(string memory name, string memory args) private pure returns (bytes4) {
        return bytes4(keccak256(bytes(string.concat(name, args))));
    }
}
