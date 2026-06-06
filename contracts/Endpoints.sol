// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Aggregator: re-exports command, admin, peer, guard, and query endpoint abstractions.
// Import this file to inherit from the full rootzero callable host surface without managing individual paths.

// Shared helpers
import { Keys } from "./blocks/Keys.sol";
import { CommandBase, CommandContext } from "./commands/Base.sol";
import { Payable } from "./core/Payable.sol";

// Commands
import { Burn, BurnHook } from "./commands/Burn.sol";
import { CreditAccount, CreditAccountHook } from "./commands/Credit.sol";
import { DebitAccount, DebitAccountHook } from "./commands/Debit.sol";
import { Deposit, DepositHook, DepositPayable, DepositPayableHook } from "./commands/Deposit.sol";
import { Payout, PayoutHook } from "./commands/Payout.sol";
import { Provision, ProvisionHook, ProvisionPayable, ProvisionPayableHook } from "./commands/Provision.sol";
import { RelayPayable, RelayPayableHook } from "./commands/Relay.sol";
import { Withdraw, WithdrawHook } from "./commands/Withdraw.sol";

// Admin commands
import { AllowAssets, AllowAssetsHook } from "./commands/admin/AllowAssets.sol";
import { Allowance, AllowanceHook } from "./commands/admin/Allowance.sol";
import { Appoint } from "./commands/admin/Appoint.sol";
import { Authorize } from "./commands/admin/Authorize.sol";
import { Destroy, DestroyHook } from "./commands/admin/Destroy.sol";
import { DenyAssets, DenyAssetsHook } from "./commands/admin/DenyAssets.sol";
import { Dismiss } from "./commands/admin/Dismiss.sol";
import { ExecutePayable } from "./commands/admin/Execute.sol";
import { Init, InitHook } from "./commands/admin/Init.sol";
import { Unauthorize } from "./commands/admin/Unauthorize.sol";

// Peer endpoints
import { PeerBase, encodePeerCall } from "./peer/Base.sol";
import { PeerAllowAssets } from "./peer/AllowAssets.sol";
import { PeerAllowance } from "./peer/Allowance.sol";
import { PeerBalancePull, BalancePullHook } from "./peer/BalancePull.sol";
import { PeerDenyAssets } from "./peer/DenyAssets.sol";
import { PeerPipePayable } from "./peer/Pipe.sol";
import { PeerDispatchPayable } from "./peer/Dispatch.sol";
import { PeerSettle } from "./peer/Settle.sol";

// Guard endpoints
import { GuardBase, encodeGuardCall } from "./guards/Base.sol";
import { Revoke } from "./guards/Revoke.sol";

// Query endpoints
import { QueryBase, encodeQueryCall } from "./queries/Base.sol";
import { AssetStatus, AssetStatusHook } from "./queries/Assets.sol";
import { GetBalances, GetBalancesHook } from "./queries/Balances.sol";
import { GetPosition, GetPositionHook } from "./queries/Positions.sol";
