// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AnnotationEvent} from "../events/Annotation.sol";
import {Blocks} from "../codec/Blocks.sol";

/// @title Clearinghouse
/// @notice Associates an entity with the host responsible for clearing it.
/// @dev The latest trusted annotation for an entity replaces the earlier value.
/// A zero host clears the association.
abstract contract Clearinghouse is AnnotationEvent {
    /// @notice Attach a clearinghouse host to `entity`.
    /// @param entity Entity receiving the annotation.
    /// @param host Host node ID responsible for clearing, or zero to clear it.
    function clearinghouse(uint entity, uint host) internal virtual {
        emit Annotation(entity, Blocks.createClearinghouse(host));
    }
}
