// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Aggregator: re-exports command, admin, and peer abstractions.
// Import this file to inherit from the full rootzero command surface without managing individual paths.

import { CommandBase, CommandContext, CommandPayable, encodeCommandCall } from "./commands/Base.sol";
import { State } from "./utils/State.sol";
import { Burn, BurnHook } from "./commands/Burn.sol";
import { CreditAccount, CreditAccountHook } from "./commands/Credit.sol";
import { DebitAccount, DebitAccountHook } from "./commands/Debit.sol";
import { Deposit, DepositHook, DepositPayable, DepositPayableHook } from "./commands/Deposit.sol";
import { PipePayable, PipePayableHook } from "./commands/Pipe.sol";
import { Provision, ProvisionHook, ProvisionPayable, ProvisionPayableHook, ProvisionFromBalance } from "./commands/Provision.sol";
import { Settle } from "./commands/Settle.sol";
import { Supply, SupplyHook } from "./commands/Supply.sol";
import { Transfer, TransferHook } from "./commands/Transfer.sol";
import { Withdraw, WithdrawHook } from "./commands/Withdraw.sol";
import { AllowAssets, AllowAssetsHook } from "./commands/admin/AllowAssets.sol";
import { Destroy, DestroyHook } from "./commands/admin/Destroy.sol";
import { Authorize } from "./commands/admin/Authorize.sol";
import { DenyAssets, DenyAssetsHook } from "./commands/admin/DenyAssets.sol";
import { Init, InitHook } from "./commands/admin/Init.sol";
import { RelocatePayable } from "./commands/admin/Relocate.sol";
import { Allocate, AllocateHook } from "./commands/admin/Allocate.sol";
import { Unauthorize } from "./commands/admin/Unauthorize.sol";
import { PeerBase, encodePeerCall } from "./peer/Base.sol";
import { PeerAssetPull, PeerAssetPullHook } from "./peer/AssetPull.sol";
import { PeerAllowAssets } from "./peer/AllowAssets.sol";
import { PeerDenyAssets } from "./peer/DenyAssets.sol";
import { PeerPull, PeerPullHook } from "./peer/Pull.sol";
import { PeerPush, PeerPushHook } from "./peer/Push.sol";
import { PeerSettle } from "./peer/Settle.sol";




