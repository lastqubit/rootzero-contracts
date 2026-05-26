// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Aggregator: re-exports all event contracts.
// Import this file to get access to every event emitter in one import.

import { AccessEvent } from "./events/Access.sol";
import { AdminEvent } from "./events/Admin.sol";
import { AssetStatusEvent } from "./events/Asset.sol";
import { BalanceEvent } from "./events/Balance.sol";
import { CollateralEvent } from "./events/Collateral.sol";
import { CommandEvent } from "./events/Command.sol";
import { Contexts } from "./events/Contexts.sol";
import { DebtEvent } from "./events/Debt.sol";
import { PositionEvent } from "./events/Position.sol";
import { ReceivedEvent } from "./events/Received.sol";
import { EventEmitter } from "./events/Emitter.sol";
import { IntroductionEvent } from "./events/Introduction.sol";
import { PeerEvent } from "./events/Peer.sol";
import { QueryEvent } from "./events/Query.sol";
import { RootedEvent } from "./events/Rooted.sol";
import { SpentEvent } from "./events/Spent.sol";
import { SwapEvent } from "./events/Swap.sol";



