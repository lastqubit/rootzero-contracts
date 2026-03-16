# rush

`rush` is the Solidity library used to build hosts and commands for the Rush protocol.

It contains the reusable contracts, utilities, and encoding helpers that Rush applications compose on top of. If you are building a Rush host, a command contract, or a small protocol extension that needs to speak Rush's id, asset, and block formats, this repo is the shared foundation.

## What You Build With It

- `Host` contracts that register with Rush discovery and expose trusted command endpoints
- `Command` contracts that execute protocol actions such as transfer, deposit, withdraw, settlement, and admin flows
- Shared request/response block parsing and writing logic
- Shared id, asset, account, and event encoding used across the protocol

## Main Entry Points

Most consumers should start from the barrel files in `contracts/`:

- `contracts/Core.sol`: core host and validation building blocks
- `contracts/Commands.sol`: base command contract plus standard command mixins
- `contracts/Blocks.sol`: block schema, readers, and writers
- `contracts/Utils.sol`: ids, assets, accounts, layout, strings, and value helpers
- `contracts/Events.sol`: reusable event emitters and event contracts

## Start Here

If you are new to Rush, read [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md) first.

It walks through:

- the host and command mental model
- which built-in commands expect `request` vs `state`
- a minimal host example
- a built-in command example
- a custom command example
- simple TypeScript request encoding

## Typical Usage

### Build a Host

Extend `Host` when you want a Rush host contract with admin command support and optional discovery registration.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "rush/contracts/Core.sol";

contract ExampleHost is Host {
    constructor(address commander, address discovery)
        Host(commander, discovery, 1, "example")
    {}
}
```

`Host` already layers in the standard admin command flows used by Rush hosts:

- `Authorize`
- `Unauthorize`
- `Relocate`

### Build a Command

Extend `CommandBase` when you want a Rush command contract that runs inside the protocol's trusted call model.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase} from "rush/contracts/Commands.sol";

contract ExampleCommand is CommandBase {
    constructor(address commander) AccessControl(commander) {}
}
```

`CommandBase` gives you the common Rush command context:

- trusted caller enforcement
- admin checks
- expiry checks
- command-to-command or command-to-host calls through encoded Rush node ids
- shared command events

## Repo Layout

- `contracts/core`: host, access control, balances, and validation primitives
- `contracts/commands`: standard command building blocks and admin commands
- `contracts/combinators`: reusable command composition helpers
- `contracts/blocks`: request/response block encoding and decoding
- `contracts/utils`: shared protocol encoding helpers
- `contracts/events`: protocol event contracts and emitters
- `contracts/discovery`: host discovery interfaces and implementation

## Install And Compile

```bash
npm install rush
npm run compile
```

The stable import surface for consumers is:

- `rush/contracts/Core.sol`
- `rush/contracts/Commands.sol`
- `rush/contracts/Blocks.sol`
- `rush/contracts/Utils.sol`
- `rush/contracts/Events.sol`

## When To Use This Repo

Use `rush` if you want to:

- create a new Rush host
- implement a new Rush command
- reuse Rush's block format and wire encoding
- share protocol-level Solidity code across multiple Rush applications

If you are looking for a full end-user app or deployment repo, this library is the lower-level protocol package rather than the full product surface.
