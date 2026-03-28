# rootzero

`rootzero` is the Solidity library used to build hosts and commands for the RootZero protocol.

It contains the reusable contracts, utilities, and encoding helpers that RootZero applications compose on top of. If you are building a RootZero host, a command contract, or a small protocol extension that needs to speak RootZero's id, asset, and block formats, this repo is the shared foundation.

## What You Build With It

- `Host` contracts that register with RootZero discovery and expose trusted command endpoints
- `Command` contracts that execute protocol actions such as transfer, deposit, withdraw, settlement, and admin flows
- Shared request/response block parsing and writing logic
- Shared id, asset, account, and event encoding used across the protocol

## Main Entry Points

Most consumers should start from the package root entrypoints:

- `@rootzero/contracts/Core.sol`: core host and validation building blocks
- `@rootzero/contracts/Commands.sol`: base command contract plus standard command mixins
- `@rootzero/contracts/Blocks.sol`: block schema, readers, and writers
- `@rootzero/contracts/Utils.sol`: ids, assets, accounts, layout, strings, and value helpers
- `@rootzero/contracts/Events.sol`: reusable event emitters and event contracts

## Start Here

If you are new to RootZero, start with the getting started guide in the repository:
https://github.com/lastqubit/rootzero-contracts/blob/main/docs/GETTING_STARTED.md

It walks through:

- the host and command mental model
- which built-in commands expect `request` vs `state`
- a minimal host example
- a built-in command example
- a custom command example
- simple TypeScript request encoding

## Typical Usage

### Build a Host

Extend `Host` when you want a RootZero host contract with admin command support and optional discovery registration.

```solidity
// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Host} from "@rootzero/contracts/Core.sol";

contract ExampleHost is Host {
    constructor(address rootzero)
        Host(rootzero, 1, "example")
    {}
}
```

`rootzero` is the trusted RootZero runtime. If it is a contract, the host also announces itself there during deployment. Use `address(0)` for a self-managed host that does not auto-register.

`Host` already layers in the standard admin command flows used by RootZero hosts:

- `Authorize`
- `Unauthorize`
- `Relocate`

### Build a Command

Extend `CommandBase` when you want a RootZero command mixin that runs inside the protocol's trusted call model. Commands are abstract contracts mixed into a host or composed as a standalone module.

```solidity
// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "@rootzero/contracts/Commands.sol";

string constant NAME = "myCommand";
string constant ROUTE = "route(uint foo, uint bar)";

abstract contract ExampleCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, ROUTE, myCommandId, 0, 0);
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        return "";
    }
}
```

`CommandBase` gives you the common RootZero command context:

- trusted caller enforcement
- admin checks
- expiry checks
- command-to-command or command-to-host calls through encoded RootZero node ids
- shared command events

## Repo Layout

- `contracts/core`: host, access control, balances, and validation primitives
- `contracts/commands`: standard command building blocks and admin commands
- `contracts/peer`: peer protocol surfaces for inter-host asset flows
- `contracts/blocks`: request/response block encoding and decoding
- `contracts/utils`: shared protocol encoding helpers
- `contracts/events`: protocol event contracts and emitters
- `contracts/interfaces`: discovery interfaces and shared external protocol surfaces

## Install And Compile

```bash
npm install @rootzero/contracts
npm run compile
```

The stable import surface for consumers is:

- `@rootzero/contracts/Core.sol`
- `@rootzero/contracts/Commands.sol`
- `@rootzero/contracts/Blocks.sol`
- `@rootzero/contracts/Utils.sol`
- `@rootzero/contracts/Events.sol`

## When To Use This Repo

Use `rootzero` if you want to:

- create a new RootZero host
- implement a new RootZero command
- reuse RootZero's block format and wire encoding
- share protocol-level Solidity code across multiple RootZero applications

If you are looking for a full end-user app or deployment repo, this library is the lower-level protocol package rather than the full product surface.
