// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Aggregator: re-exports all core protocol contracts (Access, Balances, Host, Operation, Validator).
// Import this file to bring the full host base layer into scope.

import { AccessControl } from "./core/Access.sol";
import { Balances } from "./core/Balances.sol";
import { Host } from "./core/Host.sol";
import { FailedCall, OperationBase } from "./core/Operation.sol";
import { Validator } from "./core/Validator.sol";
import { HostDiscovery } from "./core/Host.sol";
import { IHostDiscovery } from "./interfaces/IHostDiscovery.sol";



