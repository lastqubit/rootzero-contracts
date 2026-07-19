# Schema

Rootzero request and response data is encoded as a stream of typed blocks. A
schema string describes the payload body for discovery events and tooling; the
runtime block key is the compact type tag that identifies that payload layout in
the active schema context. The block alias is published separately from the
payload schema.

## Wire Format

Every block uses the same header:

```txt
[bytes4 key][uint32 payloadLen][payload]
```

`payloadLen` is big-endian and counts only payload bytes. Child blocks and list
items use the same header format.

Standard built-in block keys use:

```txt
bytes4(keccak256("#name"))
```

For example, the standard `amount` alias uses the key derived from `#amount`
and the schema body `{ bytes32 asset, uint amount }`. Custom block keys do not
have to be keccak-derived. They
are opaque `bytes4` tags and only need to be unique in the context where they are
used. A host can publish the meaning of a custom key with:

```solidity
event Schema(uint indexed host, bytes4 key, string schema, bytes32 name);
```

For example, a host-specific payment block can use a small literal, the command
selector, or any other chosen `bytes4` value as long as that key is not
overloaded in the relevant host/schema context.

## Block Syntax

A block definition has an event alias and a schema body. Fixed fields are
written in braces:

```txt
alias:  amount
schema: { bytes32 asset, uint amount }
```

A block body can reference another block alias as a child item with `#`:

```txt
{ bytes32 account, #bytes as state, #bytes as request }
```

The empty schema string `""` means the block has no structured payload. This is
used for zero-payload blocks such as `#unit` and raw dynamic blocks such as
`#bytes`.

A schema body is a comma-separated list of items. Order is significant.

```txt
{ #amount, maybe #account as recipient }
```

## Payload Layout

A block payload encodes schema items in declaration order. Fixed fields are
packed inline, and zero or more child blocks are embedded directly at their
declared positions. Because every child block carries its own header and payload
length, fixed fields may appear before, after, or between child blocks.

```txt
{ uint target, uint resources, #bytes as payload }
{ bytes32 account, #bytes as state, #bytes as request }
{ bytes4 key, #string as body, bytes32 name }
{ #bytes as left, uint op, #bytes as right }
```

There is no wrapper around embedded child blocks.

Raw dynamic bytes are represented with the reserved `#bytes` child block. Use an
alias to give those bytes a presentation name:

```txt
#bytes as payload
```

## Modifiers

Cardinality is expressed with prefix keywords:

```txt
#balance
maybe #balance
many #balance
maybe many #balance
```

- no prefix: one required item
- `maybe`: optional item
- `many`: one generic `#list` block whose payload contains repeated items
- `maybe many`: optional `#list` block

`maybe` emits no placeholder when absent. `many` wraps repeated items in one
generic list block; it does not repeat the item in place.

## Endpoint Lanes

Endpoint descriptors identify each lane with a block key and group size. In
Solidity, endpoint definition helpers accept `bytes9` lane values, with plain
`bytes4` keys and the `bytes8` values returned by `many(item)` widening
implicitly. A plain key or `many(item)` stores a zero group byte that readers
interpret as group size 1, while `bytes9(0)` or `Keys.Empty` means the endpoint
has no blocks in that lane. Use
`group(lane, size)` when a lane needs an explicit group size other than 1.

The packed descriptor stores each lane key as an 8-byte value:

```txt
[key bytes4][item bytes4]
```

A plain block key is widened into `[key][0]`, so normal endpoint declarations can
pass standard `bytes4` keys directly. A lane with a nonzero `item` describes a
generic container block: `key` is the top-level wire key and `item` is the
contained item key. The built-in `many(item)` helper creates `[Keys.List][item]`
with the default group size 1, matching the DSL form `many #item`.

Any non-empty lane resolves its key to a block alias and schema body through the
active schema context. If the item slot is nonzero, tooling also resolves that
item key in the same context. A bare list lane, `[Keys.List][0]`, is incomplete
discovery metadata because it does not say what the list contains; indexers
should reject it for self-describing endpoints.

The lane key is the prime item. Prime items may repeat at the top level for
batching. When the lane is `many #item`, the repeated prime item is the generic
LIST block and each LIST payload contains repeated `item` blocks. Later
top-level items are globals for the whole batch and are not counted as
per-operation prime blocks.

The prime item cannot be optional. If an endpoint needs a per-operation marker
with no payload, use a zero-payload block such as `#unit`.

Endpoint descriptors currently use a narrower convention than the full block
grammar: each state, input, or output lane is a single run of blocks, without
additional global items. Future protocol surfaces may use the more flexible
top-level structure.

## Field Aliases

Block aliases are published in `Schema` events. Field aliases are presentation
metadata for tooling. They do not change payload layout or runtime keys.

```txt
maybe #account as recipient
{ uint target, uint resources, #bytes as payload }
```

Field aliases may be used on any block item, including child blocks and prime
items.

Child blocks are schema references:

```txt
{ uint handler, uint resources, bytes32 key, #bytes as witness }
```

Alias resolution is context-dependent. A consumer may resolve `#context` from
standard block events, from app-specific block events, or from another active
schema context. Custom parents should define nested custom blocks from the
bottom up and reference them by alias. Consumers should reject schemas with
unresolved aliases. The runtime encoding is still an embedded child block with
the referenced key and layout.

## Field Paths

Field names and aliases may use dotted paths for offchain projection. A dotted
path does not change the block key, payload bytes, payload length, cursor
behavior, or any onchain validation. It is metadata only.

```txt
{ uint dst.portal, uint dst.resources, #bytes as dst.payload }
```

This has the same runtime layout as:

```txt
{ uint portal, uint resources, #bytes as payload }
```

Offchain tooling may decode the dotted form into a nested object:

```ts
{
  dst: {
    portal,
    resources,
    payload
  }
}
```

Encoding and decoding must still follow schema declaration order, not object
property order. Fields with the same path prefix do not need to be contiguous,
although contiguous fields are easier to read when they represent one logical
object.

Tooling should reject duplicate full paths and prefix/value collisions:

```txt
uint dst.portal, uint dst.portal    // duplicate path
uint dst, uint dst.portal           // prefix/value collision
```

The same rule applies to field aliases:

```txt
{ uint target, uint resources, #bytes as calldata.payload }
maybe #account as recipient.account
```

## Field Types

Supported field types are chain-neutral:

```txt
uint, uint8, uint16, uint32, uint64, uint128, uint256
int, int8, int16, int32, int64, int128, int256
bool
bytes1 through bytes32
```

`uint` means `uint256`; `int` means `int256`. Other integer widths, unsized
`bytes`, `string`, and array syntax are not part of the core schema DSL.

Integers are encoded big-endian. Signed integers use two's-complement encoding
for their declared width. `bool` is one byte: `0x00` for false and `0x01` for
true. `bytesN` values are encoded as exactly `N` bytes with no padding.

## Chain Resources

Fields named `portal` are routing identifiers; they are often the destination
host ID, but a transport adapter may define a different stable handle.

Fields named `resources` are chain-specific resource words. A portal adapter
interprets them for the destination runtime. Different runtimes may pack these
words differently, but a given runtime must use one stable format everywhere.
For EVM chains, the low 128 bits are native value / endowment in wei; higher
bits are reserved for execution resources such as gas.

## Protocol IDs

Account, asset, and node ID fields use one 32-byte convention:

- first byte `0x00`: opaque ID, encoded as `0x00 || bytes31(hash)`. The full
  preimage must come from a lookup table or witness data when native metadata is
  needed.
- first byte nonzero: structured ID. The value may be deconstructed according
  to its chain/runtime layout.

Opaque preimages must start with a one-byte format/hash tag; `0x01` means
keccak256. The remaining bytes are host/domain-specific until the protocol
standardizes a fuller preimage payload format.

The field name supplies the protocol role for opaque IDs. For example, a
`bytes32 asset` whose first byte is zero is still an asset in that block; it
just cannot be decoded without external context. Runtime helpers that inspect
the layout of an ID only apply to structured IDs.

## Identifiers

Block aliases use lower camelCase ASCII identifiers. Field names and aliases
use one or more lower camelCase path segments separated by dots:

```txt
[a-z][a-zA-Z0-9]*
[a-z][a-zA-Z0-9]*(\.[a-z][a-zA-Z0-9]*)*
```

Invalid examples:

```txt
Amount
asset_meta
asset-meta
0account
asset.
.asset
```

Reserved words include `maybe`, `many`, `as`, all field type names, and the
reserved block aliases `bytes` and `list`. For dotted paths, reserved words are
invalid in any path segment.

## Reserved Blocks

- `#bytes`: raw dynamic bytes, written without a body
- `#string`: UTF-8 string bytes, written without a body
- `#list`: generic list wrapper emitted by `many`

Custom input shapes should define their own context-local block key and publish
that key with a `Schema` event. Endpoint contracts can use `schema(...)` for
that publication:

```solidity
bytes4 input = schema(1, "{ bytes32 asset, uint amount }");
```

Use different numeric keys when a host needs more than one local block key. The
key can also be a selector or any other `bytes4` value that is unique in the
context where it is used. The alias names the block; the schema string describes
only the payload body.

## Standard Blocks

Common protocol schemas live in `contracts/blocks/Schema.sol`:

```txt
amount   { bytes32 asset, uint amount }
balance  { bytes32 asset, uint amount }
custody  { uint host, bytes32 asset, uint amount }
call     { uint target, uint resources, #bytes as payload }
step     { uint target, uint resources, #bytes as request }
context  { bytes32 account, #bytes as state, #bytes as request }
recover  { uint handler, uint resources, bytes32 key, #bytes as witness }
auth     { uint cid, uint deadline, #bytes as proof }
schema   { bytes4 key, #string as body, bytes32 name }
```

`Keys.sol` contains the corresponding standard runtime keys.
