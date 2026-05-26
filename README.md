# rootzero

`rootzero` is the Solidity library for building hosts and commands for the rootzero protocol.

It contains the reusable contracts, utilities, cursor parsers, and encoding helpers that rootzero applications compose on top of. If you are building a host, a command contract, or protocol tooling that needs to speak the protocol's ID, asset, account, and block formats, this repo is the shared foundation.

## Main Entry Points

Most consumers should start from the package root entry points:

- `@rootzero/contracts/Core.sol` — host, access control, balances, and validator building blocks
- `@rootzero/contracts/Endpoints.sol` — command, peer, guard, and query base contracts plus standard endpoint mixins
- `@rootzero/contracts/Cursors.sol` — cursor reader (`Cur`), block schemas, key constants, typed block helpers, and writers
- `@rootzero/contracts/Utils.sol` — IDs, assets, accounts, layout, and value helpers
- `@rootzero/contracts/Events.sol` — reusable event emitters and event contracts

## Block Wire Format

All request and response data is encoded as a binary block stream. Each block is:

```
[bytes4 key][bytes4 payloadLen][payload]
```

`key` is `bytes4(keccak256("#name"))`; see `Keys` for the full set and [`docs/Schema.md`](docs/Schema.md) for the schema format. `Cursors` parses calldata streams zero-copy via the `Cur` struct; `Writers` builds response streams into pre-allocated memory.

## Schemas, Forms, And State

Protocol blocks use schema strings and four-byte keys:

- `Schemas` describes semantic protocol blocks such as `#amount`, `#balance`, `#custody`, and `#payout`.
- `Forms` describes reusable structural blocks such as `#accountAsset` and `#accountAmount`, mostly used by queries.
- `Keys` contains the runtime `bytes4` keys derived from block names.

Every command declares its input and output pipeline state with block keys in the `Command` event. Use `Keys.Empty` when a command expects or returns no state.

The active command pipeline state is intentionally narrow: `BALANCE` and `CUSTODY` blocks are live value owned by the active account while execution is in-flight. `TRANSACTION` remains a block type for settlement messages, but it is not command pipeline state.

## Typical Usage

### Build a Host

Extend `Host` when you want a rootzero host contract with admin command support and optional discovery registration.

```solidity
// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "@rootzero/contracts/Core.sol";

contract ExampleHost is Host {
    constructor(address rootzero)
        Host(rootzero, 1, "example")
    {}
}
```

`rootzero` is the trusted runtime address. If it implements `IHostDiscovery`, the host announces itself there during deployment. Use `address(0)` for a self-managed host that does not auto-register.

### Build a Command

Extend `CommandBase` to define a command mixin that runs inside the protocol's trusted call model. Commands are abstract contracts mixed into a host.

```solidity
// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "@rootzero/contracts/Endpoints.sol";
import { Cursors, Cur, Schemas, Writer, Writers } from "@rootzero/contracts/Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

string constant NAME = "myCommand";

abstract contract ExampleCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        emit Command(host, myCommandId, NAME, "1:0:1", Schemas.Amount, Keys.Empty, Keys.Balance, false);
    }

    function myCommand(
        CommandContext calldata c
    ) external onlyCommand returns (bytes memory) {
        (Cur memory request, uint groups) = cursor(c.request, 1);
        Writer memory writer = Writers.allocBalances(groups);

        while (request.i < request.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = request.unpackAmount();
            writer.appendBalance(asset, meta, amount);
        }

        request.close();
        return writer.finish();
    }
}
```

## Repo Layout

- `contracts/core` — host, access control, balances, operation base, and signature validation
- `contracts/commands` — standard command building blocks and admin commands
- `contracts/peer` — peer protocol surfaces for inter-host asset flows and asset allow/deny
- `contracts/blocks` — block stream schema (`Schema`), cursor parsing (`Cursors`), and writers (`Writers`)
- `contracts/utils` — shared encoding helpers: IDs, assets, accounts, layout, ECDSA
- `contracts/events` — protocol event contracts and emitters
- `contracts/interfaces` — discovery interfaces and shared external protocol surfaces
- `docs` — introductory documentation

## Install and Compile

```bash
npm install @rootzero/contracts
npm run compile
```

## When To Use This Repo

Use `rootzero` if you want to:

- create a new rootzero host
- implement a new rootzero command
- reuse the protocol's block format and wire encoding
- share protocol-level Solidity code across multiple rootzero applications

If you are looking for a full end-user app or deployment repo, this library is the lower-level protocol package rather than the full product surface.
