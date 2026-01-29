# Rush Protocol

Rush is an on-chain pipeline execution engine. Users submit a sequence of **steps** that flow through a state machine, calling endpoints on trusted nodes to debit, transform, and credit assets.

## Core Concepts

### Pipeline

A pipeline is an ordered array of steps (`bytes[]`) submitted via `pipe()` or `inject()`. The executor processes each step sequentially, threading a `(head, args)` pair through the chain:

- **head** (`bytes4`): The current phase selector (ADMIN, SETUP, OPERATE, TRANSACT, PROCESS, or 0 for done)
- **args** (`bytes`): ABI-encoded context passed between steps (account, token ID, amount, etc.)

When all steps are consumed and `head != 0`, the executor auto-credits the remaining args to the user's account.

### Step Format

Each step is packed bytes with the structure:

```
[uint256 endpointId] [uint256 value] [bytes blocks...]
 32 bytes             32 bytes        variable
```

- **endpointId**: Identifies the target contract and function (see ID System below)
- **value**: ETH value for the call (currently unused, set to 0)
- **blocks**: Packed argument blocks starting at byte offset 64

### Blocks

Blocks are packed key-value segments within a step:

```
[bytes4 key] [uint32 length] [bytes data]
 4 bytes      4 bytes         variable
```

The **request block** uses key `0x00000000` and contains the ABI-encoded request object for the command. Multiple blocks can be packed sequentially; the `getBlock` function scans up to 5 blocks to find a match by key.

### Commands and Params

Commands declare their expected request format using a `params` string emitted in their constructor's `Endpoint` event. The params string uses semicolons as delimiters. The first param is the request object, which can have a custom name. For example, `creditTo(uint to)` declares a request named `creditTo` instead of the generic `request`.

## ID System

All identifiers are 256-bit unsigned integers with a fixed layout:

```
bits 224-255: selector   (function selector for endpoints, 0 for other ID types)
bits 192-223: descriptor (ACCOUNT, HOST, ENDPOINT, TOKEN, VALUE)
bits 160-191: chain      (chain ID, 0 for pure account IDs)
bits   0-159: address    (contract or account address)
```

Descriptor constants:
- `VALUE`    = `0x01010100`
- `ACCOUNT`  = `0x01010200`
- `HOST`     = `0x01010300`
- `ENDPOINT` = `0x01010400`
- `ASSET`    = `0x01010500`
- `TOKEN`    = `0x01010501`

The first 4 bytes of the endpointId (the selector) are used by `ensureAdvanceable` to validate state machine transitions via `canAdvance`.

## State Machine

The pipeline enforces a phase-based state machine. Each step's selector (extracted from the endpointId) must be valid for the current head:

```
ADMIN   -> ADMIN, AUTHORIZE, UNAUTHORIZE, RELOCATE, and all SETUP commands
SETUP   -> All SETUP commands (ADD, ALLOW, APPROVE, COLLECT, CREATE, DENY, ...)
OPERATE -> OPERATE, RELAY, RESOLVE, TRANSFORM
TRANSACT -> TRANSACT
PROCESS  -> PROCESS
```

Phase transitions happen when a command returns a different head. For example, `debitFrom` (a SETUP command) returns `(OPERATE, args)`, transitioning the pipeline from SETUP to OPERATE phase.

## Entry Points

### `pipe(uint192 deadline, bytes[] steps, bytes signed)`

The main user-facing entry point. Starts the pipeline in **SETUP** phase.

- If `signed` is empty (`0x`), uses `msg.sender` as the account
- If `signed` contains a signature, recovers the signer via ECDSA, validates the nonce, and uses the recovered address
- The deadline is checked against `block.timestamp` to prevent stale submissions
- The hash signed is `keccak256(abi.encode(steps, pipeId, deadline))`

### `inject(bytes[] steps)`

Owner-only entry point. Starts the pipeline in **ADMIN** phase with the commander's account. Used for administrative operations like authorizing nodes.

### `resume(bytes4 head, bytes args, bytes[] steps)`

Authorized-only entry point for resuming interrupted pipelines. Used by dispatchers to continue cross-node execution.

## Typical Pipeline Flow

### Debit-Credit (simplest case)

```
User -> pipe(deadline, [debitStep, creditStep], "0x")
                          |              |
                    SETUP phase    OPERATE phase
                          |              |
                    Faucet.setup   Rush.resolve
                    (debitFrom)    (creditTo)
                          |              |
                    returns         returns
                    (OPERATE,       (0, "")
                     args)          = done
```

1. Pipeline starts with `head = SETUP`
2. **debitStep** targets an external node's `setup` endpoint (e.g., Faucet). The executor calls the node via `callAddr`, which invokes `setup(account, step)`. The node's `debitFrom` logic reads the request block, debits the amount, and returns `(OPERATE, abi.encode(account, tokenId, amount, "", ""))`.
3. **creditStep** targets Rush's internal `resolve` endpoint. The executor recognizes `eid == resolveId` and calls `creditTo(args, step)` directly. The credit logic adds the amount to the user's balance and returns `(0, "")` (done).

If the pipeline runs out of steps before `head == 0`, it auto-credits via `creditTo(head, args)`.

### Authorization (admin flow)

```
Owner -> inject([authorizeStep])
                    |
              ADMIN phase
                    |
              Rush.authorize
              (self-call)
                    |
              returns (0, "")
```

The authorize command takes a request containing `uint[] hosts` (an array of host IDs to trust). It calls `access(addr, true)` for each, adding them to the `authorized` mapping.

## Architecture

### Contracts

```
Rush (main entry point)
  +-- Executor        (pipeline loop, step routing)
  +-- Validator        (ECDSA signature recovery, nonce management)
  +-- Discovery        (node announcement registry)
  +-- Node             (base: Host + Admin commands + IsTrusted query)
  +-- Endpoints        (Inject, Pipe, Resume, Balances, GetBalances)

Faucet (example external node)
  +-- Node             (base)
  +-- Endpoints        (DebitFrom, CreditTo)
```

### Executor Routing

For each step, the executor:

1. Extracts `selector = bytes4(step)` and `eid = uint(bytes32(step))`
2. Validates `canAdvance(head, selector)` via the state machine
3. Routes based on the endpoint ID:
   - `eid == setupId` -> internal `debitFrom(args, step)`
   - `eid == resolveId` -> internal `creditTo(args, step)`
   - `eid == transactId` -> internal `settle(args, step)`
   - Otherwise -> `callAddr(endpointAddr(eid), selector, args, step)`

Internal endpoints (setup, resolve, transact) are handled directly by Rush's own balance logic. External endpoints dispatch to trusted node contracts.

### Access Control

- **cmdr** (commander): Immutable address set at construction. Defaults to `address(this)` if not provided.
- **admin**: Account ID derived from the commander address.
- **authorized**: Mapping of trusted external addresses.
- **isTrusted(addr)**: Returns true if `addr == cmdr || addr == address(this) || authorized[addr]`.

Commands are protected by `onlyTrusted`, meaning only the commander (Rush) or authorized nodes can call them. This ensures normal users can only interact through `pipe()`, not by calling command functions directly.

### Balances

Rush maintains an internal double-mapping `balances[account][id]` where:
- `account` is an account ID (derived from a user address)
- `id` is a token/asset ID

The `getBalances(account, ids[])` query function allows reading multiple balances in a single call.

### Nodes

A node is a contract that implements one or more command interfaces. When deployed, it:

1. Sets its commander (`cmdr`) for access control
2. Announces itself to a discovery contract via `announce(hostId, blockNumber, name)`
3. Emits `Endpoint` events for each command it supports, including the endpoint ID, ABI string, and params string

To use a node in a pipeline, it must be authorized on the Rush contract via `inject([authorizeStep])`.

### Faucet Node

A minimal node that provides infinite liquidity for testing. It implements `debitFrom` and `creditTo` with a fixed balance constant of `1000 * 10^18`. The Faucet's `debitFrom` resolves the amount against this fixed balance, and `creditTo` is a no-op that emits a Balance event.
