// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @notice Conventional identifiers shared by endpoint execution lanes.
library Lanes {
    /// @dev Decoder lane containing endpoint input blocks.
    uint8 internal constant Input = 1;
    /// @dev Decoder lane containing command state blocks.
    uint8 internal constant State = 2;
    /// @dev Writer lane containing regular endpoint output blocks.
    uint8 internal constant Output = 3;
    /// @dev Writer lane containing deferred transaction blocks.
    uint8 internal constant Transactions = 4;
}
