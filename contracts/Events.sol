// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Aggregator: re-exports all event contracts.
// Import this file to get access to every event emitter in one import.

import { AccessEvent } from "./events/Access.sol";
import { AssetEvent } from "./events/Asset.sol";
import { BalanceEvent } from "./events/Balance.sol";
import { CollateralEvent } from "./events/Collateral.sol";
import { CommandEvent } from "./events/Command.sol";
import { DebtEvent } from "./events/Debt.sol";
import { DepositEvent } from "./events/Deposit.sol";
import { Erc721PositionEvent } from "./events/Erc721.sol";
import { EventEmitter } from "./events/Emitter.sol";
import { GovernedEvent } from "./events/Governed.sol";
import { HostAnnouncedEvent } from "./events/Host.sol";
import { ListingEvent } from "./events/Listing.sol";
import { PeerEvent } from "./events/Peer.sol";
import { QueryEvent } from "./events/Query.sol";
import { RootZeroEvent } from "./events/RootZero.sol";
import { WithdrawalEvent } from "./events/Withdraw.sol";



