// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Keys} from "../Base.sol";
import {AdminEvent} from "../../events/Admin.sol";

/// @title AdminBase
/// @notice Shared base for admin commands.
abstract contract AdminBase is CommandBase, AdminEvent {}
