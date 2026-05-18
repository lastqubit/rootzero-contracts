# Schema DSL v2 Draft

This document captures the proposed simplified schema format. It is a working
draft, not a final spec.

The main goals are:

- make blocks easy to recognize visually
- keep block definitions compact
- avoid postfix modifiers like `?` and `[]`
- allow aliases as explicit schema metadata
- describe dynamic payloads with one simple rule: fixed fields first, then an
  optional child-block tail
- support nested child blocks with explicit parent boundaries

## Block Atoms

A block starts with `#`. Its payload is written inside `{ ... }`.

```txt
#balance { uint amount }
#amount { bytes32 asset, bytes32 meta, uint amount }
#account { bytes32 account }
```

A block without braces has no payload.

```txt
#unit
#reset
```

Empty braces are not allowed. A zero-payload block must omit braces:

```txt
#unit      // valid
#unit { }  // invalid
```

This rule applies to every block name. For example, `#amount` is a zero-payload
block named `amount`; it is not shorthand for the standard amount fields. A
real amount block must provide its full definition:

```txt
#amount { bytes32 asset, bytes32 meta, uint amount }
```

Solidity constants may still hold common full definitions, but the schema string
itself remains explicit.

A schema is a comma-separated list of items. The same separator is used at the
top level and inside block bodies.

Top-level items:

```txt
#amount { bytes32 asset, bytes32 meta, uint amount },
maybe #account { bytes32 account }
```

Nested items:

```txt
#payment { bytes32 asset, bytes32 meta, uint amount, maybe #fee { uint amount } }
```

Braces define parent-child boundaries. Commas separate siblings inside the
current boundary.

Order is significant. Top-level items, fixed fields, child blocks in a
child-block tail, and repeated items inside a list are interpreted in the exact
order declared by the schema.

Trailing commas are invalid at every level.

Comments are not part of schema strings.

## Prefix Modifiers

Cardinality is expressed with prefix keywords before the block atom.

```txt
#balance { uint amount }
maybe #balance { uint amount }
many #balance { uint amount }
maybe many #balance { uint amount }
```

Meanings:

- no prefix: one required item
- `maybe`: optional item
- `many`: list item
- `maybe many`: optional list item

`many` replaces the current postfix `[]` form. It means one list block with the
generic list key. The list block's payload is a block stream containing repeated
items of the declared shape.

The generic list key is derived from:

```txt
#list
```

For example:

```txt
many #asset { bytes32 asset, bytes32 meta }
```

encodes as one `LIST` block whose payload contains zero or more `asset` blocks.
This is distinct from top-level batching, where the prime item itself is
repeated without a list wrapper.

Lists may contain zero items. An empty list is encoded as a present generic list
block with an empty payload. This is distinct from an absent `maybe many` list,
where no list block is emitted.

`many` never repeats the block in place. It always wraps the declared block in
one generic list block.

The repeated item is a normal block item. It can have fixed fields followed by
a child-block tail just like any other block.
The repeated item may also be `#data` or `#bytes`.
Nested `many` is allowed anywhere a block item is allowed.

`maybe many` makes the entire generic list block optional. It does not make
individual list items optional.

`maybe` emits no placeholder when the item is absent. When present, the item is
encoded exactly like the non-optional form.

The prefix modifiers apply only to block items. They cannot be applied to fixed
fields:

```txt
maybe uint amount  // invalid
many uint amount   // invalid
```

If a value needs optionality or list semantics, make it a child block:

```txt
maybe #fee { uint amount }
many #rate { uint value }
```

## Prime And Global Items

Prime blocks are decided by convention.

There are only two cases:

- the schema is empty, meaning it has no request items at all
- the schema is non-empty, and its first top-level item is the prime item

Only the exact empty string `""` means no schema. Whitespace-only strings are
invalid.

The prime item may be repeated at the top level as many times as needed to
create a batch request. This repetition is not a `many` list wrapper; it is
ordinary top-level batching.

Any block item can be the prime item, including a `many` list item. In that case
the prime run consists of generic list blocks, one list block per operation.

The prime item cannot be optional. `maybe #x { ... }` and
`maybe many #x { ... }` are invalid as the first top-level item. A non-empty
schema must have a required prime item. If there is no meaningful
per-operation payload, use a zero-payload prime such as `#unit`.

For example:

```txt
#amount { bytes32 asset, bytes32 meta, uint amount },
maybe #account { bytes32 account }
```

Here `amount` is the prime item. A request may contain any number of consecutive
top-level `amount` blocks for the batch, followed by the optional global
`account` support block.

Top-level items after the first item are global support items. They apply to the
whole batch and are not counted as per-operation prime blocks.

When a non-empty schema has no natural per-operation request payload, the
recommended convention is to use `#unit` as the prime item.

```txt
#unit,
maybe #account { bytes32 account }
```

`#unit` is a real zero-payload block. It is encoded like any other block, with a
runtime key and a zero payload length. This keeps the convention simple: either
there are no blocks at all, or there is a prime block, even if that prime block
does not carry payload. A batch with three unit inputs contains three top-level
`#unit` blocks.

In principle, any zero-payload block could serve this role. `#unit` is the
recommended standard name.

An empty string still means there are no request items at all.

## Aliases

Aliases are presentation metadata for off-chain tools. They do not change the
payload layout or the aliased block's own runtime key. If an alias appears on a
child declaration inside a parent block body, it is part of the parent block's
canonical form and can affect the parent key.

Aliases use postfix `as`.

```txt
#balance { uint amount } as available
maybe #account { bytes32 account } as recipient
many #balance { bytes32 asset, bytes32 meta, uint amount } as balances
maybe many #amount { bytes32 asset, bytes32 meta, uint amount } as payments
```

This keeps operational modifiers before the block and display labels after it.

Aliases are allowed on any block item, including the prime item.

## Key Derivation

Keys are derived from the block name only. The hash input is the block atom,
including the `#` prefix and excluding any fields, child blocks, modifiers, or
aliases.

```txt
bytes4(keccak256("#balance"))
```

The full schema still defines the payload layout:

```txt
#balance { bytes32 asset, bytes32 meta, uint amount }
```

but its runtime key is derived from `#balance` alone.

Blocks should not be overloaded. A block name should have one clear protocol
meaning, so the name itself is enough to identify the block type. These two
schemas would produce the same key and should not coexist as distinct protocol
blocks:

```txt
#fee { uint amount }
#fee { uint value }
```

Name conflicts are allowed because names do not affect payload encoding. When
off-chain tools present conflicting sibling names, they should append zero-based
suffixes in encounter order.

For example:

```txt
#range { uint amount, uint amount }
```

presents as:

```txt
amount0
amount1
```

The same suffixing convention applies to conflicting aliases or child
presentation names inside one parent.

Duplicate child block types inside the same tail are allowed. Order remains
significant, and presentation tools should suffix conflicting child names in
encounter order.

Modifiers and aliases do not change runtime keys:

```txt
maybe #account { bytes32 account } as recipient
```

uses the same emitted block key as:

```txt
#account { bytes32 account }
```

Both forms can use the same `account` unpack helper.

Likewise, these all use the same `#payment` parent key and the same `#fee`
child key:

```txt
#payment { uint amount, #fee { uint value } }
#payment { uint amount, maybe #fee { uint value } }
#payment { uint amount, #fee { uint value } as fee }
```

Reserved generic-key forms follow the same name-only rule:

- `#bytes` uses the key derived from `#bytes`. It is a reserved raw bytes
  block with no body.
- `#data` uses the key derived from `#data`, regardless of its declared body.
- `many #x { ... }` emits a generic list block whose key is derived from
  `#list`, then stores repeated `#x` items inside the list payload.

Formatting normalization still matters for schema descriptors, tooling, and
human-readable discovery output, but it does not affect runtime keys.

The canonical normalized schema form uses:

- one space after a block name before `{`
- one space after `{`
- one space before `}`
- comma followed by one space
- single spaces between type and field name
- prefixes written as `maybe`, `many`, or `maybe many`
- no extra whitespace

```txt
#name { type field, type field, maybe #child { type field } }
```

## Fixed Fields And Tails

A block payload has one fixed part and may have one dynamic child-block tail.

```txt
block = fixed fields + optional child-block stream
```

Fixed fields always come first. Once the first child block item appears, the
remainder of the payload is a block stream. Raw dynamic bytes are represented by
the reserved `#bytes` child block.

Invalid:

```txt
#x { #child { uint a }, uint b }
#x { #bytes as payload, uint a }
#x { #bytes payload }
```

## Wire Format

The block wire header stays the same as the current system:

```txt
[bytes4 key][uint32 payloadLen][payload]
```

`payloadLen` is encoded big-endian and covers only the payload bytes, not the
8-byte header.

Every block, including child blocks and list items, uses the same header format.

## Field Types

Schema field types should be chain-neutral. Types tied to one runtime family,
such as EVM `address`, are not allowed in the core schema DSL.

Initial supported types are protocol-defined, not runtime-defined:

```txt
uint
uint8
uint16
uint32
uint64
uint128
uint256
int
int8
int16
int32
int64
int128
int256
bool
bytes1 through bytes32
```

`uint` means `uint256`. `int` means `int256`.

Other integer widths, such as `uint24` or `int40`, are not part of the core DSL.

Unsized `bytes` is not a field type. Use the reserved `#bytes` block for raw
dynamic bytes.

`string` is not part of the core schema DSL. Text payloads should use `#bytes`
and define their interpretation at the command or tooling layer.

Array syntax is not part of the core schema DSL. Forms such as `uint[]`,
`bytes32[]`, and `#x[]` are invalid. Repetition is expressed with `many` on a
block item.

## Identifiers

Block names, field names, and aliases use simple ASCII identifiers without
underscores:

```txt
[a-z][a-zA-Z0-9]*
```

Valid:

```txt
amount
assetMeta
hostAccountAmount
```

Invalid:

```txt
Amount
asset_meta
asset-meta
asset.meta
0account
```

The required style is lower camelCase.

Parsing is case-sensitive. `#Amount` and `#amount` are different block names.
Keywords and field types are lowercase.

Reserved words cannot be used as block names, field names, or aliases. Reserved
words include prefix/alias keywords, reserved block names, and field type names:

```txt
maybe
many
as
uint
int
bool
bytes
uint8
uint16
uint32
uint64
uint128
uint256
int8
int16
int32
int64
int128
int256
bytes1 through bytes32
```

The block names `bytes`, `data`, and `list` are reserved generic-key block names.
`#bytes` is the reserved raw bytes block and must be written without a body.
It cannot be renamed inline; use an alias when the raw bytes need a presentation
name:

```txt
#bytes as payload
```

This is invalid:

```txt
#bytes payload
```

Users should not write `#list { ... }` directly. List blocks are authored with
`many`.
The generic data block follows the normal zero-payload rule, so `#data` is valid
as an empty generic data block.

## Field Encoding

Fixed fields are packed in declaration order. The encoded size comes from the
declared type width.

Examples:

```txt
uint8   -> 1 byte
uint16  -> 2 bytes
uint32  -> 4 bytes
uint64  -> 8 bytes
uint128 -> 16 bytes
uint256 -> 32 bytes
int8    -> 1 byte
int16   -> 2 bytes
int32   -> 4 bytes
int64   -> 8 bytes
int128  -> 16 bytes
int256  -> 32 bytes
bool    -> 1 byte
bytes4  -> 4 bytes
bytes20 -> 20 bytes
bytes32 -> 32 bytes
```

`uint` is encoded as `uint256`. `int` is encoded as `int256`.

Integers are encoded big-endian. Signed integers use two's-complement encoding
for their declared width.

Examples:

```txt
uint16 1  -> 0x0001
int16 -1  -> 0xffff
int16 -2  -> 0xfffe
uint256 1 -> 31 zero bytes followed by 0x01
int256 -1 -> 32 bytes of 0xff
```

`bool` is encoded as one byte:

```txt
false -> 0x00
true  -> 0x01
```

Other bool byte values are invalid.

`bytesN` values are encoded as exactly `N` bytes with no padding.

The fixed head length is the sum of the encoded fixed field sizes. If the block
has a child-block tail, the tail starts immediately after the fixed head.

## No Structural Wrapper Blocks

The v2 format should not need special structural block forms such as `bundle`.
Every block already has the same general shape:

```txt
fixed fields + optional child-block tail
```

If a block needs to carry child blocks, it declares those child blocks directly
in its tail:

```txt
#payment { bytes32 asset, bytes32 meta, uint amount, maybe #fee { uint amount } }
```

This replaces the need for a separate bundle wrapper. The parent block is the
container.

## Generic Custom Block

Most named blocks get their own runtime key. Sometimes a schema needs a custom
payload shape but should not create a new key. For that case, v2 should have one
reserved generic block with a stable key.

Draft name:

```txt
#data
```

`#data` always uses the same runtime key, regardless of the fields or child
blocks declared inside it. Its schema body describes how to interpret the
payload, but does not create a new key.

Aside from key derivation, `#data` behaves like any other block. It can have
fixed fields followed by a child-block tail.

The generic data key is derived from:

```txt
#data
```

Examples:

```txt
#data { uint host }
#data { uint foo, bytes32 tag }
#data { uint foo, #rate { uint amount } }
#data { #bytes as payload }
```

Use `#data` when the payload shape is local/custom and a stable generic key is
preferred over a new shape-specific key.

## Data Shorthand

If a schema string starts with a fixed field type instead of an item prefix or
`#`, it is shorthand for one top-level `#data` block.

```txt
uint host
```

expands to:

```txt
#data { uint host }
```

Multiple fields and a child-block tail are also allowed:

```txt
uint foo, bytes32 tag, maybe #rate { uint amount }
```

expands to:

```txt
#data { uint foo, bytes32 tag, maybe #rate { uint amount } }
```

The shorthand must start with a fixed field. It cannot start with a block tail:

```txt
#rate { uint amount }
```

is a normal top-level `rate` block, not data shorthand.

Use the explicit form when the generic data block has no fixed fields:

```txt
#data { #rate { uint amount } }
```

## Child-Block Tails

Nested `#` items inside a block define a child-block tail.

```txt
#config { uint foo, #rate { uint amount } }
```

This means:

- `config` has fixed field `uint foo`
- the remainder of the `config` payload is a child-block stream
- that tail stream contains a `rate` block

Child-block tails are encoded directly as raw child block bytes inside the
parent payload. There is no extra stream wrapper block. The parent payload
length bounds the tail, and each child block's own header delimits that child.

Tail items can use the same prefix modifiers and aliases:

```txt
#config { uint foo, maybe #rate { uint amount } }
#portfolio { bytes32 account, many #balance { bytes32 asset, bytes32 meta, uint amount } }
#payment { bytes32 asset, bytes32 meta, uint amount, maybe #fee { uint amount } as fee }
```

Once the first nested block item appears, the rest of the payload is the
child-block tail. Fixed fields may not appear after tail items.

Inline tail blocks do not need terminators. Their closing brace ends the child
block, and commas separate sibling fields or blocks.

Optional children inside a present parent block may be absent while the parent
block is still emitted. For example:

```txt
#payment { uint amount, maybe #fee { uint value } }
```

may encode as a `payment` block containing only the fixed `amount` field and no
`fee` child.

If a required parent contains only optional children and all children are absent,
the parent is still emitted with an empty payload. The optionality belongs to the
marked child, not to the parent.

## Nested Child Blocks

Nested child blocks should be supported. A block should always behave the same
way wherever it appears: it can have fixed fields followed by an optional
child-block tail.

Because child blocks can themselves have child blocks, the schema needs an
unambiguous way to show which parent each child belongs to.

Braces define parent-child boundaries.

```txt
#config { uint foo, #rate { uint amount }, #limit { uint max } }
```

This is easy to read as one `config` block with two tail children:

```txt
config
  fixed: uint foo
  tail:
    rate
    limit
```

If `limit` belongs to `rate`, it is nested inside the `rate` braces:

```txt
#config { uint foo, #rate { uint amount, #limit { uint max } } }
```

The boundary rule preserves the invariant that every block, top-level or child,
has the same shape: fixed fields followed by at most one tail.

For example, braces can express this shape:

```txt
config
  fixed: uint foo
  tail:
    rate
      fixed: uint amount
      tail:
        proof
          tail:
            bytes
```

Braces are the parent-child boundary syntax for nested block tails.

## Raw Bytes Blocks

Raw dynamic bytes are represented by the reserved `#bytes` child block.

```txt
#data { #bytes as payload }
#call { uint target, uint value, #bytes as payload }
```

`#bytes` has no body and no fixed fields or child blocks. It cannot have an
inline name. If a schema needs a presentation name for the bytes, use an alias:

```txt
#bytes as payload
```

The encoded `#bytes` block uses the normal block header:

```txt
[BYTES_KEY][uint32 payloadLen][raw bytes]
```

## Examples

Simple protocol block:

```txt
#amount { bytes32 asset, bytes32 meta, uint amount }
```

Optional support block:

```txt
maybe #account { bytes32 account }
```

List block:

```txt
many #asset { bytes32 asset, bytes32 meta }
```

Fixed block with optional child-block tail:

```txt
#payment { bytes32 asset, bytes32 meta, uint amount, maybe #fee { uint amount } }
```

Multiple top-level items:

```txt
#amount { bytes32 asset, bytes32 meta, uint amount },
maybe #account { bytes32 account }
```

Aliased items:

```txt
maybe #account { bytes32 account } as recipient,
many #balance { bytes32 asset, bytes32 meta, uint amount } as balances
```

## Mapping From Current DSL

Current:

```txt
balance(uint amount)
balance(uint amount)?
balance(uint amount)[]
balance(uint amount)[]?
```

Draft:

```txt
#balance { uint amount }
maybe #balance { uint amount }
many #balance { uint amount }
maybe many #balance { uint amount }
```

Current:

```txt
frame = amount(bytes32 asset, bytes32 meta, uint amount) +& fee(uint amount)?
```

Draft:

```txt
#payment { bytes32 asset, bytes32 meta, uint amount, maybe #fee { uint amount } }
```

Current:

```txt
empty; account(bytes32 account)?
```

Draft:

```txt
#unit,
maybe #account { bytes32 account }
```

## Open Questions

No open questions recorded yet.
