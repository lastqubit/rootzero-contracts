// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title Flags
/// @notice Shared endpoint behavior flags encoded in both endpoint IDs and descriptors.
/// @dev Bit 6 is reserved for endpoint-defined custom behavior.
library Flags {
    /// @dev Endpoint accepts nonzero native value.
    uint8 internal constant Funded = 1 << 0;
    /// @dev Endpoint is restricted to the admin account.
    uint8 internal constant Admin = 1 << 1;
    /// @dev Endpoint accepts nonzero native value and is restricted to the admin account.
    uint8 internal constant AdminFunded = Admin | Funded;
    /// @dev Endpoint takes ownership of the remaining pipeline steps.
    uint8 internal constant Handoff = 1 << 7;
    /// @dev Endpoint accepts nonzero native value and takes ownership of the remaining pipeline steps.
    uint8 internal constant HandoffFunded = Handoff | Funded;
}
