// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Aggregator: re-exports command, admin, port, guard, and query endpoint abstractions.
// Import this file to inherit from the full rootzero callable host surface without managing individual paths.

// Shared endpoint hooks
import {CreditAccountHook, DebitAccountHook, PostHook, RepayHook, SettleHook} from "./core/Settlement.sol";

// Commands
import {CommandBase} from "./commands/Base.sol";
import {Allocate, AllocateHook} from "./commands/Allocate.sol";
import {Burn, BurnHook} from "./commands/Burn.sol";
import {CreditAccount, CreditAccountInternal} from "./commands/Credit.sol";
import {DebitAccount, DebitAccountInternal} from "./commands/Debit.sol";
import {Deposit, DepositHook, DepositPayable, DepositPayableHook} from "./commands/Deposit.sol";
import {Payout, PayoutHook} from "./commands/Payout.sol";
import {Provision, ProvisionHook, ProvisionPayable, ProvisionPayableHook} from "./commands/Provision.sol";
import {RecoverPayable, RecoverPayableHook} from "./commands/Recover.sol";
import {Repay, RepayPayable, RepayPayableHook} from "./commands/Repay.sol";
import {RelayPayable, RelayBalancePayable, RelayPayableHook} from "./commands/Relay.sol";
import {Settle, SettlePayable, SettlePayableHook, SettleInternal} from "./commands/Settle.sol";
import {Withdraw, WithdrawHook} from "./commands/Withdraw.sol";

// Admin commands
import {AdminBase} from "./commands/admin/Base.sol";
import {AllowAssets, AllowAssetsHook} from "./commands/admin/AllowAssets.sol";
import {Allowance, AllowanceHook} from "./commands/admin/Allowance.sol";
import {Annotate} from "./commands/admin/Annotate.sol";
import {Appoint} from "./commands/admin/Appoint.sol";
import {Authorize} from "./commands/admin/Authorize.sol";
import {DenyAssets, DenyAssetsHook} from "./commands/admin/DenyAssets.sol";
import {Dismiss} from "./commands/admin/Dismiss.sol";
import {ExecutePayable} from "./commands/admin/Execute.sol";
import {Unauthorize} from "./commands/admin/Unauthorize.sol";

// Port endpoints
import {PortBase} from "./ports/Base.sol";
import {AllowAssetsPort} from "./ports/AllowAssets.sol";
import {AllowancePort} from "./ports/Allowance.sol";
import {RedeemBalancePort, RedeemBalanceHook} from "./ports/Redeem.sol";
import {CreditAccountPort} from "./ports/Credit.sol";
import {DebitAccountPort} from "./ports/Debit.sol";
import {DenyAssetsPort} from "./ports/DenyAssets.sol";
import {PipePayablePort} from "./ports/Pipe.sol";
import {DispatchPayablePort, DispatchPayableHook} from "./ports/Dispatch.sol";
import {PostPort} from "./ports/Post.sol";

// Guard endpoints
import {GuardBase} from "./guards/Base.sol";
import {Revoke, RevokeAllowance, RevokeAsset} from "./guards/Revoke.sol";

// Query endpoints
import {QueryBase} from "./queries/Base.sol";
import {AssetStatus, AssetStatusHook} from "./queries/Assets.sol";
import {GetBalances, GetBalancesHook} from "./queries/Balances.sol";
