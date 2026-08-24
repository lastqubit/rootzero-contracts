# Schema

Rootzero input and response data is encoded as a stream of typed blocks. A
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
used. A host can publish the meaning of a custom key as an annotation:

```solidity
event Annotation(uint indexed entity, bytes data);
#schema { uint spec, #string as body, bytes32 name }
```

Annotation merge behavior is defined by the annotation block type rather than
by the `Annotation` event. A `#schema` annotation is identified by its entity
and the block key encoded in `spec`: distinct keys accumulate, while the latest
trusted claim for the same key replaces the earlier one. Other annotation types
may define additive, historical, or explicitly revocable behavior instead.

The standard `#action { uint action }` annotation assigns one primary semantic
action to an entity. The latest trusted value replaces the previous value, and
`Actions.None` clears the classification.

For example, a host-specific payment block can use a small literal, the command
selector, or any other chosen `bytes4` value as long as that key is not
overloaded in the relevant host/schema context.

## Block Syntax

A block definition has an event alias and a schema body. A schema body is one
of these forms:

```txt
""                  empty or raw payload
fields              structured payload
{ fields }          equivalent braced structured payload
many #item          top-level custom list payload
{ many #item }      equivalent braced top-level list payload
```

One optional pair of outer braces may wrap any non-empty schema body. The
braces are presentation-only and never change its wire layout:

```txt
alias:  amount
schema: bytes32 asset, uint amount
also valid: { bytes32 asset, uint amount }
```

Consumers must remove one matching pair of outer braces, when present, before
parsing the comma-separated item sequence. Unmatched braces and additional
outer brace layers are invalid.

A block body can reference another block alias as a child item with `#`:

```txt
{ bytes32 account, #bytes as state, #bytes as input }
```

The empty schema string `""` means the block has no structured payload. This is
used for raw dynamic blocks such as `#bytes`.

Every block key also has an empty wire form consisting of its header with a
zero payload length. Empty blocks are structurally present but contain no body
to decode. Existing semantic decoders remain strict: for example,
`unpackBalance` rejects an empty `#balance` unless its caller detects and
consumes the empty form first.

When a parent block is non-empty, every child block declared by its schema is
represented by a header in declaration order. A child without a value uses its
empty form rather than being omitted. An empty parent is terminal, so its body
and nested child headers are not present.

A structured schema body is a comma-separated list of items. Order is
significant.

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
{ bytes32 account, #bytes as state, #bytes as input }
{ uint spec, #string as body, bytes32 name }
{ #bytes as left, uint op, #bytes as right }
```

There is no wrapper around embedded child blocks.

Raw dynamic bytes are represented with the reserved `#bytes` child block. Use an
alias to give those bytes a presentation name:

```txt
#bytes as payload
```

## Modifiers

Empty-value acceptance and repeated items are expressed with prefix keywords:

```txt
#balance
maybe #balance
many #balance
```

- no prefix: one required item whose ordinary value rules determine whether its
  payload may be empty
- `maybe`: one required header whose payload may be empty
- `many`: one required list header containing zero or more repeated items

These modifiers are offchain hints describing the forms accepted by the
onchain consumer; they do not change runtime validation. `#bytes`, `#string`,
and lists accept empty payloads as ordinary values, so applying `maybe` to them
has no additional meaning and tooling may normalize it away.

A `many` item alongside any sibling items wraps its repeated values in one
generic `#list` block; it does not repeat the item in place. The list header
remains present when it has no items and carries a zero payload length:

```txt
{ uint id, many #asset as assets }
```

When the item sequence of an emitted custom schema consists of exactly one
`many` item, the custom schema key identifies the outer list block instead. Its
payload contains the repeated items directly. Optional outer braces and an
item alias do not affect this rule:

```txt
schema key: 0x00000001
schema body: many #asset
equivalent body: { many #asset }
also equivalent: many #asset as assets
wire value: [0x00000001][length][ASSET][ASSET]...
```

This convention gives a top-level list a discoverable, context-local type while
retaining the generic `#list` key for lists whose type is supplied by an
enclosing schema.

## Endpoint Lanes

Endpoint descriptors identify each lane with a block key and group size. In
Solidity, endpoint definition helpers accept block specs such as `Specs.Amount`.
A zero group is interpreted as group size 1, while `Specs.Empty` means the
endpoint has no blocks in that lane. Use `group(spec, size)` when a lane needs
an explicit group size other than 1.

The packed descriptor uses these lane layouts:

```txt
state   [key:4][group:1]
input   [key:4][group:1]
output  [key:4][min:4][max:4][hint:3][group:1]
reserve [reserved:4]
tx      [transactions:1]
flags   [flags:1]
```

Flag bits 0 and 1 are the protocol-defined `funded` and `admin` flags. Bits 6
and 7 are reserved for endpoint-defined custom flags; bits 2 through 5 remain
reserved for future protocol flags.

Each lane directly identifies its top-level block key. Output lanes retain their
size bounds and allocation hint so execution can reconstruct the output spec and
initialize its writer directly. Four descriptor-level bytes are reserved after
the lane metadata. The Solidity output decoder returns a left-aligned,
writer-ready spec that retains its encoded group and clears its reserved fields.
`Specs.group` returns the effective group, interpreting an encoded zero as one
for a non-empty spec.

Any non-empty lane resolves its key to a block alias and schema body through the
active schema context. A top-level list lane uses the key of its emitted custom
`many` schema; the descriptor treats it like every other direct lane spec.

The lane key is the prime item. Prime items may repeat at the top level for
batching. Later top-level items are globals for the whole batch and are not
counted as per-operation prime blocks.

An endpoint may accept the empty form of its prime block as a per-operation
marker. The header remains present, so empty prime blocks still participate in
run counting and batching.

Endpoint descriptors currently use a narrower convention than the full block
grammar: each state, input, or output lane is a single run of blocks, without
additional global items. Endpoint decoder opening requires that run to consume
the complete supplied lane; a trailing block with another key is invalid.
Lower-level cursor scanning may still intentionally open only a prefix run.
Those lower layers retain only the raw block count; descriptor strides are
applied and lane groups reconciled once when an endpoint execution opens.
Future protocol surfaces may use the more flexible top-level structure.

For commands, complete-lane validation is also a state-safety rule. State is a
linear value owned by the current pipeline step, not optional context that a
command may disregard. Every command must account for the complete supplied
state by consuming it, transforming and returning it, forwarding it intact, or
reverting. A command whose descriptor declares an empty state lane must reject
non-empty state. A command that accepts state must validate the complete stream
against its declared schema; accepting only a prefix and silently dropping the
remainder is invalid.

## Live Pipeline State

`#balance`, `#debt`, `#custody`, and `#position` are live state carried between
command steps for the active account. Balance carries only the asset side, debt
carries only the liability side, and position carries both:

```txt
balance  { bytes32 asset, uint amount }
debt     { bytes32 liability, uint debt }
position { bytes32 asset, uint amount, bytes32 liability, uint debt }
```

The position layout is deliberately the flat combination of the balance and
debt layouts; it is not a nested Solidity struct. The asset side represents
value acquired or controlled, and the liability side represents value owed or
required. Commands may preserve or replace either side and return a new
position. The terminal `settle` command consumes the pair. Debt and position
state are transient protocol state; rewriting either does not by itself create,
discharge, or replace an obligation persisted by a host or external protocol.
The responsible command hook must perform or verify those effects. A command
must not ignore supplied debt or position state: it must explicitly consume,
transform, forward, or reject it, so an obligation cannot disappear
accidentally.

The repayment commands reflect the state shapes directly. `repay` and
`repayPayable` consume `#debt` and return empty state. `repayPosition` and
`repayPositionPayable` consume `#position`, repay its liability side, and return
the released asset side as `#balance`.

This representation supports ordinary forward transformations as well as
backward composition. For example, an exact-output route can carry its desired
asset while successive hops replace the upstream liability:

```txt
position(C, 100, C, 100)
→ position(C, 100, B, 50)
→ position(C, 100, A, 25)
→ settle
```

“Backward” describes how requirements are composed from the desired result
toward the source. Pipeline execution is not reversed: STEP blocks always run
forward in their encoded order. Exact-output routing is only an example;
borrowing, refinancing, collateral transformation, callback obligations,
cross-host claims, fees, and netting can use the same position state.

## Field Aliases

Block aliases are published in `#schema` annotations. Field aliases are presentation
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

## Presentation Order

An item may use `at N` to select its zero-based position in the offchain
presentation of its enclosing item sequence. This is projection metadata only:
it does not change wire order, payload offsets, block keys, encoding, or onchain
decoding.

```txt
{
  uint32 fee,
  int32 tickSpacing,
  uint hook,
  #bytes as hookData,
  #position at 0,
  many #swapHop
}
```

The wire order remains:

```txt
fee, tickSpacing, hook, hookData, position, swapHop
```

The offchain presentation order is:

```txt
position, fee, tickSpacing, hook, hookData, swapHop
```

To construct the presentation order, tooling first reserves every position
named by `at`, then fills the remaining positions with unannotated items in
their original declaration order. This permits one item to be repositioned
without annotating every sibling. Multiple `at` annotations may be used when
more positions need to be fixed explicitly.

An `at` position must be less than the number of sibling items, and two siblings
must not select the same position. Tooling must reject duplicate or out-of-range
positions. An item without `at` retains its order relative to the other
unannotated items. Each nested schema body applies presentation ordering
independently; a `many` declaration occupies one position in its enclosing body.

`at` follows the complete item, including any field alias:

```txt
uint amount at 0
#bytes as hookData at 2
maybe #account as recipient at 1
many #swapHop at 3
```

Encoders and decoders must always process items in declaration order. Consumers
may apply `at` only after decoding when constructing an offchain object, tuple,
table, or user interface.

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

Restricting fixed bytes to the power-of-two widths `bytes1`, `bytes2`,
`bytes4`, `bytes8`, `bytes16`, and `bytes32` is under consideration, but has
not been decided. Until that decision is made, the schema DSL continues to
allow every `bytesN` width from 1 through 32.

Integers are encoded big-endian. Signed integers use two's-complement encoding
for their declared width. `bool` is one byte: `0x00` for false and `0x01` for
true. `bytesN` values are encoded as exactly `N` bytes with no padding.

## Chain Resources

Fields named `portal` identify destination portal hosts. By convention, the
value is the host ID of the destination portal implementation. Core encoding
and dispatch pass the value through unchanged; transport hooks are responsible
for any validation or route resolution they require.

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

Reserved words include `maybe`, `many`, `as`, `at`, all field type names, and the
reserved block aliases `bytes` and `list`. For dotted paths, reserved words are
invalid in any path segment.

## Reserved Blocks

- `#bytes`: raw dynamic bytes, written without a body
- `#string`: UTF-8 string bytes, written without a body
- `#list`: generic list wrapper emitted by nested `many`

Custom input shapes should define their own context-local block spec and publish
it with a `#schema` annotation. Endpoint contracts can use `schema(...)` to
construct and publish that spec:

```solidity
uint input = schema(1, 64, 64, 64, "{ bytes32 asset, uint amount }", bytes32(0));
```

Use different numeric keys when a host needs more than one local block key. The
key can also be a selector or any other `bytes4` value that is unique in the
context where it is used. The numeric arguments after the key are the minimum,
maximum, and allocation hint payload sizes. The alias names the block; the
schema string describes only the payload body.

## Standard Blocks

Common protocol schemas live in `contracts/codec/Schema.sol`:

```txt
amount   { bytes32 asset, uint amount }
balance  { bytes32 asset, uint amount }
custody  { uint host, bytes32 asset, uint amount }
call     { uint target, uint resources, #bytes as payload }
step     { uint cmd, uint resources, #bytes as input }
context  { bytes32 account, #bytes as state, #bytes as input }
recover  { uint handler, uint resources, bytes32 key, #bytes as witness }
schema   { uint spec, #string as body, bytes32 name }
```

`Keys.sol` contains the corresponding standard runtime keys.
