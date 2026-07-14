// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title Selectors
/// @notice Canonical ABI selector derivation for rootzero endpoint types.
library Selectors {
    /// @notice Derive the ABI selector for a command entrypoint.
    /// @param name Command function name.
    /// @return Selector for `name((bytes32,bytes,bytes))`.
    function command(string memory name) internal pure returns (bytes4) {
        return derive(name, "((bytes32,bytes,bytes))");
    }

    /// @notice Derive the ABI selector for a port entrypoint.
    /// @param name Port function name.
    /// @return Selector for `name(bytes)`.
    function port(string memory name) internal pure returns (bytes4) {
        return direct(name);
    }

    /// @notice Derive the ABI selector for a query entrypoint.
    /// @param name Query function name.
    /// @return Selector for `name(bytes)`.
    function query(string memory name) internal pure returns (bytes4) {
        return direct(name);
    }

    /// @notice Derive the ABI selector for a guard action entrypoint.
    /// @param name Guard action function name.
    /// @return Selector for `name(bytes)`.
    function guard(string memory name) internal pure returns (bytes4) {
        return direct(name);
    }

    /// @dev Derive a direct endpoint selector with a single `bytes` argument.
    /// @param name Endpoint function name.
    /// @return Selector for `name(bytes)`.
    function direct(string memory name) private pure returns (bytes4) {
        return derive(name, "(bytes)");
    }

    /// @dev Derive an ABI selector from a function name and argument signature suffix.
    /// @param name Function name.
    /// @param args Parenthesized ABI argument signature.
    /// @return First four bytes of the function signature hash.
    function derive(string memory name, string memory args) private pure returns (bytes4) {
        return bytes4(keccak256(bytes(string.concat(name, args))));
    }
}
