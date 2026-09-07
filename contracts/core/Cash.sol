// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @notice Hook implemented by hosts that credit native value to accounts.
abstract contract CashinHook {
    /// @notice Credit an exact chain-asset amount already held by the host to `account`.
    /// @dev Returning successfully asserts that the complete amount was credited.
    /// Implementations must revert when the requested amount cannot be credited.
    /// Implementations are responsible for account validation, including zero-account policy.
    /// Callers must consume the amount from their budget so it cannot be reused.
    /// @param account Account whose chain asset is credited.
    /// @param amount Native-asset amount to credit.
    function cashin(bytes32 account, uint amount) internal virtual;
}

/// @notice Hook implemented by hosts that withdraw chain assets from accounts.
abstract contract CashoutHook {
    /// @notice Withdraw an exact chain-asset amount from `account`.
    /// Called once per chain-asset BALANCE block in state by the cashout command.
    /// @dev Implementations must revert when the requested amount cannot be withdrawn.
    /// @param account Account whose chain asset is withdrawn.
    /// @param amount Native-asset amount to withdraw.
    function cashout(bytes32 account, uint amount) internal virtual;
}
