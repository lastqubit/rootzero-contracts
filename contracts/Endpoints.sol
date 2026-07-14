// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Aggregator: re-exports command, admin, port, guard, and query endpoint abstractions.
// Import this file to inherit from the full rootzero callable host surface without managing individual paths.

// Shared helpers
import { Keys } from "./blocks/Keys.sol";
import { CommandBase, CommandContext } from "./commands/Base.sol";
import { EndpointBase, Lane } from "./core/Endpoint.sol";
import { Payable } from "./core/Payable.sol";

// Commands
import { Burn, BurnHook } from "./commands/Burn.sol";
import { CreditAccount, CreditAccountHook } from "./commands/Credit.sol";
import { DebitAccount, DebitAccountHook } from "./commands/Debit.sol";
import { Deposit, DepositHook, DepositPayable, DepositPayableHook } from "./commands/Deposit.sol";
import { Payout, PayoutHook } from "./commands/Payout.sol";
import { Provision, ProvisionHook, ProvisionPayable, ProvisionPayableHook } from "./commands/Provision.sol";
import { RecoverHook, RecoverPayable } from "./commands/Recover.sol";
import { RelayPayable, RoutePayableHook } from "./commands/Relay.sol";
import { Withdraw, WithdrawHook } from "./commands/Withdraw.sol";

// Admin commands
import { AdminBase } from "./commands/admin/Base.sol";
import { AllowAssets, AllowAssetsHook } from "./commands/admin/AllowAssets.sol";
import { Allowance, AllowanceHook } from "./commands/admin/Allowance.sol";
import { Appoint } from "./commands/admin/Appoint.sol";
import { Authorize } from "./commands/admin/Authorize.sol";
import { DenyAssets, DenyAssetsHook } from "./commands/admin/DenyAssets.sol";
import { Dismiss } from "./commands/admin/Dismiss.sol";
import { ExecutePayable } from "./commands/admin/Execute.sol";
import { Label } from "./commands/admin/Label.sol";
import { Unauthorize } from "./commands/admin/Unauthorize.sol";

// Port endpoints
import { PortBase } from "./ports/Base.sol";
import { PortAllowAssets } from "./ports/AllowAssets.sol";
import { PortAllowance } from "./ports/Allowance.sol";
import { PortRedeemBalance, RedeemBalanceHook } from "./ports/Redeem.sol";
import { PortCreditAccount } from "./ports/Credit.sol";
import { PortDebitAccount } from "./ports/Debit.sol";
import { PortDenyAssets } from "./ports/DenyAssets.sol";
import { PortPipePayable } from "./ports/Pipe.sol";
import { PortDispatchPayable } from "./ports/Dispatch.sol";
import { PortSettle } from "./ports/Settle.sol";

// Guard endpoints
import { GuardBase } from "./guards/Base.sol";
import { Revoke } from "./guards/Revoke.sol";

// Query endpoints
import { QueryBase } from "./queries/Base.sol";
import { AssetStatus, AssetStatusHook } from "./queries/Assets.sol";
import { GetBalances, GetBalancesHook } from "./queries/Balances.sol";
