# Schema

Rootzero request and response data is encoded as a stream of typed blocks. A
schema string describes payload layout for discovery events and tooling; the
runtime block key is derived only from the block name.

## Wire Format

Every block uses the same header:

```txt
[bytes4 key][uint32 payloadLen][payload]
```

`payloadLen` is big-endian and counts only payload bytes. Child blocks and list
items use the same header format.

The block key is:

```txt
bytes4(keccak256("#name"))
```

For example, `#amount { bytes32 asset, bytes32 meta, uint amount }` uses the key
derived from `#amount`. Blocks must not be overloaded: one block name should have
one protocol meaning.

## Block Syntax

A block starts with `#`. Fixed fields are written in braces:

```txt
#amount { bytes32 asset, bytes32 meta, uint amount }
#account { bytes32 account }
```

A block without braces has no payload:

```txt
#unit
#bytes
```

Empty braces are invalid. A zero-payload block must omit braces.

A schema is a comma-separated list of items. Order is significant.

```txt
#amount { bytes32 asset, bytes32 meta, uint amount },
maybe #account { bytes32 account }
```

## Payload Layout

A block payload has fixed fields first, followed by an optional child-block tail.
Once a child block appears, no more fixed fields may follow.

```txt
#call { uint target, uint value, #bytes as payload }
#context { bytes32 account, #bytes as state, #bytes as request }
#pipe { uint value, #context { bytes32 account, #bytes as state, #bytes as request } }
```

The tail is embedded directly as child block bytes. There is no wrapper around a
child-block tail.

Raw dynamic bytes are represented with the reserved `#bytes` child block. Use an
alias to give those bytes a presentation name:

```txt
#bytes as payload
```

## Modifiers

Cardinality is expressed with prefix keywords:

```txt
#balance { bytes32 asset, bytes32 meta, uint amount }
maybe #balance { bytes32 asset, bytes32 meta, uint amount }
many #balance { bytes32 asset, bytes32 meta, uint amount }
maybe many #balance { bytes32 asset, bytes32 meta, uint amount }
```

- no prefix: one required item
- `maybe`: optional item
- `many`: one `#list` block whose payload contains repeated items
- `maybe many`: optional `#list` block

`maybe` emits no placeholder when absent. `many` wraps repeated items in one
generic list block; it does not repeat the item in place.

## Prime Items

The empty string `""` means no schema. Whitespace-only schemas are invalid.

For a non-empty schema, the first top-level item is the prime item. Prime items
may repeat at the top level for batching. Later top-level items are globals for
the whole batch and are not counted as per-operation prime blocks.

The prime item cannot be optional. If a command needs a per-operation marker with
no payload, use a zero-payload block such as `#unit`.

## Aliases

Aliases are presentation metadata for tooling. They do not change payload layout
or runtime keys.

```txt
maybe #account { bytes32 account } as recipient
#call { uint target, uint value, #bytes as payload }
```

Aliases may be used on any block item, including child blocks and prime items.

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

## Identifiers

Block names, field names, and aliases use lower camelCase ASCII identifiers:

```txt
[a-z][a-zA-Z0-9]*
```

Invalid examples:

```txt
Amount
asset_meta
asset-meta
0account
```

Reserved words include `maybe`, `many`, `as`, all field type names, and the
reserved block names `bytes`, `data`, and `list`.

## Reserved Blocks

- `#bytes`: raw dynamic bytes, written without a body
- `#data`: generic/custom payload block
- `#list`: generic list wrapper emitted by `many`

Use `#data` when a local schema needs a stable generic key:

```txt
#data { uint foo, bytes32 tag }
#data { #bytes as payload }
```

If a schema string starts with a fixed field type, it is shorthand for one
top-level `#data` block:

```txt
uint foo, bytes32 tag
```

expands to:

```txt
#data { uint foo, bytes32 tag }
```

## Standard Blocks

Common protocol schemas live in `contracts/blocks/Schema.sol`:

```txt
#amount { bytes32 asset, bytes32 meta, uint amount }
#balance { bytes32 asset, bytes32 meta, uint amount }
#custody { uint host, bytes32 asset, bytes32 meta, uint amount }
#call { uint target, uint value, #bytes as payload }
#step { uint target, uint value, #bytes as request }
#context { bytes32 account, #bytes as state, #bytes as request }
#pipe { uint value, #context { bytes32 account, #bytes as state, #bytes as request } }
#auth { uint cid, uint deadline, #bytes as proof }
```

`Keys.sol` contains the corresponding runtime keys.
