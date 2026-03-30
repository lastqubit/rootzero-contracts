# Getting Started With rootzero

This guide is for developers who want to build on rootzero without reading the whole codebase first.

If you remember only one thing, remember this:

- A `Host` is your application contract.
- A command is an entrypoint the rootzero runtime is allowed to call.
- Requests and responses are passed around as typed byte blocks.

## The Mental Model

rootzero moves data through a small command context:

```solidity
struct CommandContext {
    uint target;
    bytes32 account;
    bytes state;
    bytes request;
}
```

In practice:

- `account` is the user account the command is acting for.
- `request` is the new input for this command.
- `state` is data produced by an earlier command in a pipeline.
- `target` is the command id you expect to receive, or `0`.

Most built-in commands follow a simple pattern:

- read blocks from `request` or `state`
- apply your host logic
- return new blocks

## Step 1: Start With A Host

The smallest useful rootzero app is a host contract.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "@rootzero/contracts/Core.sol";

contract ExampleHost is Host {
    constructor(address rootzero)
        Host(rootzero, 1, "example")
    {}
}
```

What the constructor arguments mean:

- `rootzero`: the trusted rootzero runtime allowed to call commands
- `1`: your host version
- `"example"`: your host namespace

If `rootzero` is a contract, the host announces itself there during deployment. If you pass `address(0)`, the host becomes self-managed and does not auto-register.

## Step 2: Reuse A Built-In Command

The easiest way to integrate is to inherit a built-in command module and implement its hook.

This example adds `DebitAccount`, which turns `AMOUNT` blocks in `request` into `BALANCE` blocks in the response:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "@rootzero/contracts/Core.sol";
import {DebitAccount} from "@rootzero/contracts/Commands.sol";
import {ensureAssetRef} from "@rootzero/contracts/Utils.sol";

contract ExampleHost is Host, DebitAccount {
    mapping(bytes32 account => mapping(bytes32 assetRef => uint amount)) internal balances;

    constructor(address rootzero)
        Host(rootzero, 1, "example")
    {}

    function debitAccount(
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) internal override {
        bytes32 ref = ensureAssetRef(asset, meta);
        balances[account][ref] -= amount;
    }
}
```

Why this is a good first step:

- you do not need to write block parsing yourself
- you get the standard rootzero command surface
- you only implement the business rule that is unique to your app

## Step 3: Understand What Built-In Commands Consume

The built-in commands are easiest to use when you know which blocks they expect.

### Commands That Read `request`

- `deposit`: reads `AMOUNT` blocks, returns `BALANCE`
- `transfer`: reads `AMOUNT` plus `RECIPIENT`
- `debitAccountToBalance`: reads `AMOUNT`, returns `BALANCE`
- `provision`: reads `AMOUNT` plus `NODE`, returns `CUSTODY`
- `pipe`: reads `STEP` blocks and runs them in order

### Commands That Read `state`

- `withdraw`: reads `BALANCE`, optionally reads `RECIPIENT` from `request`
- `creditBalanceToAccount`: reads `BALANCE`, optionally reads `RECIPIENT` from `request`
- `settle`: reads `TX`
- `fund`: reads `BALANCE` from `state` and `NODE` from `request`

This is the main pattern to keep in mind:

- use `request` for the command's direct input
- use `state` when a previous command already produced the input

## Step 4: Send A Simple Request

For a host that supports `deposit`, a request with one `AMOUNT` block is enough.

TypeScript helper example:

```ts
import { ethers } from "ethers";
import { encodeAmountBlock } from "../test/helpers/blocks.js";

const asset = ethers.zeroPadValue("0x01", 32);
const meta = ethers.ZeroHash;
const amount = 100n;

const ctx = {
  target: 0n,
  account: "0x...", // 32-byte rootzero account id
  state: "0x",
  request: encodeAmountBlock(asset, meta, amount),
};

await host.deposit(ctx);
```

What happens:

1. `deposit` reads the `AMOUNT` block from `ctx.request`.
2. Your host applies its deposit logic.
3. The command returns one `BALANCE` block for each deposited amount.

## Step 5: Create A Custom Command

When the built-in modules are not enough, add your own command entrypoint.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "@rootzero/contracts/Core.sol";
import {CommandContext} from "@rootzero/contracts/Commands.sol";
import {toCommandId} from "@rootzero/contracts/Utils.sol";

bytes32 constant NAME = "myCommand";
string constant ROUTE = "route(uint foo, uint bar)";

contract ExampleHost is Host {
    uint immutable myCommandId = toCommandId(NAME, address(this));

    constructor(address rootzero)
        Host(rootzero, 1, "example")
    {
        emit Command(host, NAME, ROUTE, myCommandId, 0, 0);
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        c.request;
        return "";
    }
}
```

There are three important ideas here:

- every custom command gets a deterministic command id
- you announce it with the `Command` event
- `onlyCommand(myCommandId, c.target)` ensures the trusted caller hit the right endpoint

## Step 6: Read Route Data Inside A Custom Command

Route blocks are a good fit for command-specific parameters.

If your request contains a `route(uint foo, uint bar)` block, your command can:

- treat it as the command-specific payload
- decode it however your app expects
- keep the rest of the rootzero request format unchanged

For simple projects, it is perfectly fine to:

- publish the route schema string in the `Command` event
- encode the route bytes off-chain
- decode the route bytes inside the command

## Step 7: Return State With Writers

When your command needs to build response blocks manually, use `Writers`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Writers} from "@rootzero/contracts/Blocks.sol";
import {Writer} from "@rootzero/contracts/Schema.sol";

function buildBalances() internal pure returns (bytes memory) {
    Writer memory writer = Writers.alloc(108 * 2);
    Writers.appendBalance(writer, bytes32(uint256(1)), bytes32(0), 50);
    Writers.appendBalance(writer, bytes32(uint256(2)), bytes32(0), 75);
    return Writers.done(writer);
}
```

Use this when your command needs to return:

- balances
- custodies
- transactions

If you are only consuming built-in commands, you often will not need to touch writers directly.

## A Tiny End-To-End Example

Imagine you want a host that keeps internal balances and lets rootzero debit them.

1. Deploy a host that inherits `Host` and `DebitAccount`.
2. Store balances in your own mapping.
3. Implement `debitAccount(account, asset, meta, amount)`.
4. Send `debitAccountToBalance` a request containing one or more `AMOUNT` blocks.
5. rootzero returns `BALANCE` blocks representing the debited amounts.

That is already a valid and useful integration.

## Which Files To Open Next

If you want to learn by example, these are the best files to read next:

- `examples/1-Host.sol`: smallest host
- `examples/2-Basic.sol`: host plus a built-in command hook
- `examples/3-Command.sol`: custom command id and command event
- `examples/MapBalance.sol`: transforming returned balance state
- `test/commands.test.ts`: concrete request and response examples
- `test/helpers/blocks.ts`: block encoders you can reuse in off-chain tooling

## Common Mistakes

- Passing data in `state` when the command expects it in `request`
- Forgetting to emit a `Command` event for a custom command
- Using the wrong `target` value for `onlyCommand`
- Trying to parse raw bytes manually when a built-in reader already exists
- Starting with a custom command when a built-in module already matches the job

## Recommended Learning Order

1. Deploy a plain `Host`.
2. Add one built-in command such as `DebitAccount` or `Deposit`.
3. Use the TypeScript block helpers to build requests.
4. Only then add a custom command with a route block.

That path keeps the first integration small and easy to debug.
