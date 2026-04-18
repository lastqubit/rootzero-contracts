// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Erc721Position(bytes32 indexed account, bytes32 asset, bytes32 meta, uint position, uint qid)";

/// @notice Emitted when the lifecycle state of an ERC-721-backed position changes.
abstract contract Erc721PositionEvent is EventEmitter {
    /// @param account Account identifier that owns or is associated with the position.
    /// @param asset Asset identifier for the ERC-721 class.
    /// @param meta Asset metadata slot, typically carrying the token-specific position context.
    /// @param position Context-specific position value; positive means active and 0 means closed.
    /// @param qid Query ID associated with the position lookup or reporting context.
    event Erc721Position(bytes32 indexed account, bytes32 asset, bytes32 meta, uint position, uint qid);

    constructor() {
        emit EventAbi(ABI);
    }
}
