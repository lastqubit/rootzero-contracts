// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Block stream:
// - encoding is [bytes4 key][bytes4 payloadLen][payload]
// - `payloadLen` covers only the block payload
// - payload layout is block-specific
//
// Extensible payloads:
// - self payload may be [head][dynamic tail]
// - head layout is implied by the block key
// - one dynamic field may consume the rest of self payload without its own length prefix
// - reserved extensible forms keep one fixed key while their declared field list remains descriptive schema metadata
// - chain-specific payload blocks are encoded using the local chain/runtime's native conventions
// - on EVM-family chains, `evm(<fields...>)` payloads use standard ABI tuple encoding via `abi.encode(...)`
//   and can be decoded with `abi.decode`
// - chain-specific payload blocks are request-only escape hatches and should never be used for pipeline state
// - prefer ordinary protocol blocks whenever possible; chain-specific payload blocks should be a last resort
// - prefer frames for typed custom payloads; reserved extensible blocks such as `data(...)`
//   should be used only when a stable protocol-level key or opaque escape hatch is needed
//
// Schema DSL:
// - `;` separates top-level items
// - command, peer, and query schemas have the top-level form `prime`, `prime; global; global`,
//   `empty; global; global`, or `""` for no request items at all
// - the first top-level item is the prime item unless it is the schema-only `empty` sentinel
// - the prime item must have one runtime key; helpers consume the consecutive run of blocks with
//   that key as the per-operation batch, and `Command.shape` is defined over those prime runs
// - `empty` emits no block, has no runtime key, and must only appear as the first top-level item
//   before global blocks; it means the schema has no prime item
// - top-level items after the prime item or `empty` are global batch support blocks: they apply to
//   the whole batch, may be searched or consumed separately by the command, and are not counted as
//   per-operation prime blocks
// - `&` bundles adjacent blocks into one bundle block
// - `+` frames adjacent fixed-layout block payloads into one frame block
// - `+&` appends the following block to a frame as a full block-stream item, preserving its header
// - use one `+&` per appended tail block, e.g. `amount(...) +& fee(...) +& data(...)`
// - leading `&` is shorthand for an anonymous bundle
// - leading `+&` is shorthand for an anonymous frame with only a block-stream tail
// - `&`, `+`, and `+&` follow the same grouping and normalization rules, except they emit different payload forms
// - `name = a & b` introduces a named bundle item with a local key derived from the raw input string
// - `name = a + b` introduces a named frame item with a local key derived from the raw input string
// - `alias: item` attaches a presentation alias to the following schema item for off-chain APIs,
//   docs, and UI labels
// - `bundle = a & b` introduces an anonymous child bundle item
// - `frame = a + b` introduces an anonymous child frame item, like `bundle = ...` and `list = ...`
// - `(fields...)` in item position is shorthand for an anonymous frame with those fields
// - `(fields...)` inside an existing frame introduces anonymous flattened frame fields without a nested frame key
// - postfix `[]` marks a repeated list in the simple suffix form, e.g. `asset(...)[]`
// - postfix `?` marks an optional item, e.g. `account(...)?`
// - `name[] = a & b` introduces a named list with a local key derived from the raw input string
// - `name? = a & b` introduces an optional named structural item
// - `name[]? = a & b` introduces an optional named list; `?[]` is invalid
// - `list = a & b` introduces an anonymous list whose repeated item is the bundled shape `a & b`
// - `bundle? = a & b`, `frame? = a + b`, and `list? = a & b` introduce optional anonymous structural items
// - empty entries are ignored, but structural markers are preserved after normalization
// - aliases are presentation metadata: they do not add bytes, headers, fields, or wrappers,
//   and they do not change the payload layout of the item they label
// - aliases are not stripped before on-chain local-key derivation; when a named structural item is keyed by
//   bytes4(keccak256(bytes(rawSchemaInput))), any alias text present in that raw string is part of identity
// - off-chain presentation should use `alias:` when present, otherwise the schema item name when available
// - if sibling presentation names collide, off-chain tools should append zero-based suffixes in encounter order,
//   e.g. `amount(...) + amount(...)` presents as `amount0` and `amount1`
// - when possible, off-chain tools should preserve item grouping for repeated schemas, e.g. `amount0.asset`,
//   `amount0.meta`, `amount0.amount`, then `amount1.asset`, `amount1.meta`, `amount1.amount`
// - if fields within one presentation group collide, off-chain tools should suffix those field names in
//   encounter order, e.g. `(uint amount, uint amount)` presents as `amount0` and `amount1`
// - optionality is schema metadata only; when an optional item is present, it uses the same encoding as the
//   non-optional form, and when absent, no placeholder block is emitted
// - optional children inside a present bundle, list item, or `+&` frame tail may be absent while the
//   parent structural block is still emitted; for example `& account(...)?` and `+& account(...)?`
//   can encode as an empty BUNDLE or empty FRAME when the account child is absent
// - optional `?` is not allowed on flattened `+` frame members because frame fields have no child key or length;
//   use `(fields...)?` as an optional frame item, make the whole frame optional, or use `+&` for
//   optional block-stream tail items
// - grouping parentheses are not part of the DSL; parentheses are only used in block field lists
//   and anonymous frame field groups
// - anonymous frame field groups in item position are promoted to anonymous frame items, so `(fields...)[]`
//   means a list of anonymous frame items and `(fields...)?` means an optional anonymous frame item
// - anonymous frame field groups inside an existing frame are flattened fields, not nested frame items, and
//   cannot be appended with `+&`
// - `+` binds tighter than `&`, so `a & b + c` normalizes as `a & (b + c)`
// - `+&` binds like `+`, so `a & b +& c` normalizes as `a & (b +& c)`
// - if `&` appears, the result remains a bundle even when only one non-empty child remains
// - if `+` appears, the result remains a frame even when only one non-empty child remains
// - if `+&` appears, the result remains a frame even when only one non-empty child remains
// - after ignoring empty entries, repeated adjacent separators collapse while preserving bundle/frame/list shape
// - bundled blocks preserve member order, so `a & b` differs from `b & a`
// - a bundle block's self payload is an embedded normal block stream of its bundled members
// - bundled members keep their ordinary block encoding, so dynamic blocks are allowed inside bundles
// - a list block's self payload is an embedded normal block stream representing the repeated items
// - a frame block's self payload is the concatenated payload fields of its framed members
// - framed members do not keep their ordinary block headers; the emitted schema defines the frame layout
// - framed members must be fixed-layout block forms because frame payloads contain no child lengths or block keys
// - anonymous frame field groups must also be fixed-layout and contribute only their fields, in order
// - `+&` members keep their ordinary block encoding inside the frame payload, so dynamic blocks are allowed there
// - each block-stream tail member is introduced with `+&`; after the first `+&`, fixed-layout `+` members
//   may not follow
// - frames may be bundled like ordinary block items, but bundles/lists cannot be framed
// - prime blocks of the same type should be grouped together so the prime run is contiguous
// - primary / driving blocks should be the prime item; auxiliary batch-wide blocks should follow
//   as global `;` siblings
// - `data(<fields...>)`, `evm(<fields...>)`, `query(<fields...>)`, and `response(<fields...>)`
//   are reserved extensible schema forms whose keys are always
//   `Keys.Data`, `Keys.Evm`, `Keys.Query`, and `Keys.Response` respectively
// - these extensible forms work like dynamic `bytes` blocks: they may carry arbitrary
//   payload bytes while keeping one fixed key per semantic block type
// - prefer `frame = ...`, `(fields...)`, and `+&` tails over `data(...)` when the payload
//   can be described by the schema DSL; frames give off-chain tools typed layouts and better generated APIs
// - `evm(<fields...>)` differs from bundle/list payloads: its bytes are not an embedded block stream
// - `evm(uint foo, uint bar)` is a schema declaration only; on-chain the block key is still `Keys.Evm`
//   and the payload can be decoded from `bytes payload` using the local runtime's native decoder
// - on EVM, `evm(bool flag)` occupies one full 32-byte ABI word, exactly like `abi.encode(flag)`
// - anonymous `&` compiles to a `Keys.Bundle` block whose self payload is the bundled member block stream
// - anonymous `[]` compiles to a `Keys.List` block whose self payload is the repeated item block stream
// - anonymous `+` compiles to a `Keys.Frame` block whose self payload is the framed member payload fields
// - anonymous `+&` compiles to a `Keys.Frame` block whose self payload is fixed framed fields
//   followed by an embedded normal block-stream tail
// - bare `(fields...)` compiles to a `Keys.Frame` block whose self payload is those fields
// - named lists, bundles, and frames use bytes4(keccak256(bytes(rawSchemaInput))) as their block key
// - named structural keys are custom/local identifiers, not global protocol keys; formatting is part of identity
// - `payment: frame = amount(...) +& fee(...)` means an anonymous frame whose runtime key is still `Keys.Frame`,
//   with `payment` as its off-chain presentation name
// - `quote: payment = amount(...) + fee(...)` means a named frame with presentation alias `quote`;
//   its local runtime key is derived from the full raw schema string including `quote:`
// - `frame = debit: amount(...) + credit: amount(...)` means the two flattened amount groups should be
//   presented off-chain as `debit` and `credit`, while encoding remains the same as without aliases
// - `frame = amount(...) + amount(...)` has the same encoding as the aliased form above, but off-chain tools
//   should present the groups as `amount0` and `amount1`
// - `asset(...)[]` means a list whose repeated item is the block `asset(...)`
// - `account(...)?` means an optional account block
// - `steps[] = asset(...) & account(...)` means a named list whose repeated item is the bundle
//   `asset(...) & account(...)`
// - `steps[]? = asset(...) & account(...)` means that named list may be absent
// - `memo? = evm(bytes payload)` means an optional named local item whose payload, when present, is EVM-encoded
// - `payment = amount(...) + fee(...)` means a named frame whose payload is
//   `asset | meta | amount | fee` and whose on-chain key is derived from that raw schema string
// - `payment = amount(...) + (uint fee, uint rate)` means a named frame whose payload is
//   `asset | meta | amount | fee | rate`, without inventing a child block name for the extra fields
// - `payment = (uint fee, uint rate)` means a named frame whose payload is `fee | rate`
// - `payment = amount(...) +& fee(...)` means a named frame whose payload is
//   `asset | meta | amount | [fee key | fee len | fee amount]`
// - `payment = amount(...) +& fee(...) +& data(bytes memo)` means a named frame whose payload is
//   `asset | meta | amount | [fee key | fee len | fee amount] | [data key | data len | memo]`
// - `payment = amount(...) +& fee(...)?` means a named frame with an amount prefix and optional fee block tail
// - `payment = amount(...) +& list? = fee(...)` means a named frame with an amount prefix and
//   an optional anonymous list block tail
// - `payment = amount(...)? + fee(...)` is invalid because `amount(...)` would be an optional flattened frame member
// - `(uint fee)` means an anonymous frame with one `fee` field
// - `(uint fee)[]` means a list of anonymous frames whose repeated item has one `fee` field
// - `(uint fee)?` means an optional anonymous frame with one `fee` field
// - `amount(...) & (uint fee)` means a bundle containing an amount block and an anonymous fee frame
// - `amount(...) +& (uint fee)` is invalid because `+&` appends existing block-stream items, not field groups
// - `amount(...) & fee(...) + account(...)` means `amount(...) & (fee(...) + account(...))`;
//   it compiles to a bundle containing one amount block followed by one frame block
// - `amount(...) & fee(...) +& account(...)` means `amount(...) & (fee(...) +& account(...))`;
//   it compiles to a bundle containing one amount block followed by one frame block with an account block tail
// - `bundle = account(...) & evm(bytes payloadData)` means an anonymous child bundle with those bundled members
// - `bundle? = account(...) & auth(...)` means that anonymous bundle may be absent
// - `frame = amount(...) + fee(...)` means an anonymous child frame with those framed payload fields
// - `frame? = amount(...) + fee(...)` means that anonymous frame may be absent
// - `frame = amount(...) +& fee(...)` means an anonymous child frame with amount fields plus a fee block tail
// - `list = asset(...) & account(...)` means an anonymous child list whose repeated item is the
//   bundle `asset(...) & account(...)`
// - `list? = fee(...)` means that anonymous list may be absent
// - `"amount(...) &"` and `"& amount(...)"` both normalize to a bundle containing one `amount(...)` child
// - `"& account(...)?"` normalizes to a bundle containing one optional `account(...)` child
// - `"amount(...) +"` and `"+ amount(...)"` both normalize to a frame containing one `amount(...)` payload
// - `"amount(...) +&"` and `"+& amount(...)"` both normalize to a frame containing one `amount(...)` block
// - `"+& account(...)?"` normalizes to a frame containing an optional `account(...)` block-stream tail
// - `"amount(...)?"` normalizes to an optional amount block; `"amount(...)?[]"` is invalid
// - canonical blocks are `amount(...)` for request amounts, `balance(...)` for state balances,
//   `allocation(...)` for host-scoped provision requests, `allowance(...)` for host-scoped caps,
//   `custody(...)` for host-scoped state,
//   `minimum(...)` for result floors, `maximum(...)` for spend ceilings, and `quantity(...)`
//   for plain scalar amounts
// - `auth(uint cid, uint deadline, bytes proof)` is a proof-separator block and must be emitted last
//
// Pipeline state:
// - `balance(...)` and `custody(...)` are live, linear state in the active command pipeline
// - pipeline state belongs to the active account while the pipeline is executing
// - while a balance or custody is in-flight as pipeline state, it is not simultaneously persisted
//   in another ledger/store by this protocol
// - commands must preserve, transform, settle, or intentionally consume pipeline state
// - request blocks such as `amount(...)`, `allocation(...)`, `allowance(...)`, `payout(...)`,
//   `minimum(...)`, and `maximum(...)` express intent, constraints, or references
// - request and value/response blocks are not live state
//
// Signed blocks:
// - an authenticated input segment ends with one trailing AUTH block
// - auth is typically grouped with the signed payload in one bundle, with AUTH as the final member
// - only the final AUTH is treated specially; earlier AUTH blocks remain ordinary signed bytes
// - the signed slice runs from the segment start through the AUTH head, excluding only AUTH proof bytes
// - `cid` binds the signature to one command; `deadline` acts as expiry and nonce
// - current helpers assume proof layout `[bytes20 signer][bytes65 sig]`

/// @title Schemas
/// @notice Human-readable ABI-signature string constants for each block type.
/// These strings are the canonical source from which `Keys` constants are derived
/// and are used when emitting schema descriptors in command events.
library Schemas {
    string constant Empty = "empty";
    string constant Node = "node(uint id)";
    string constant Account = "account(bytes32 account)";
    string constant Asset = "asset(bytes32 asset, bytes32 meta)";
    string constant Balance = "balance(bytes32 asset, bytes32 meta, uint amount)";
    string constant Amount = "amount(bytes32 asset, bytes32 meta, uint amount)";
    string constant Minimum = "minimum(bytes32 asset, bytes32 meta, uint amount)";
    string constant Maximum = "maximum(bytes32 asset, bytes32 meta, uint amount)";
    string constant Custody = "custody(uint host, bytes32 asset, bytes32 meta, uint amount)";
    string constant Payout = "payout(bytes32 account, bytes32 asset, bytes32 meta, uint amount)";
    string constant Allocation = "allocation(uint host, bytes32 asset, bytes32 meta, uint amount)";
    string constant Allowance = "allowance(uint host, bytes32 asset, bytes32 meta, uint amount)";
    string constant Transaction = "transaction(bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)";
    string constant Call = "call(uint target, uint value, bytes payload)";
    string constant Step = "step(uint target, uint value, bytes request)";
    string constant Bounty = "bounty(uint amount, bytes32 relayer)";
    string constant Quantity = "quantity(uint amount)";
    string constant Fee = "fee(uint amount)";
    string constant Rate = "rate(uint value)";
    string constant Bounds = "bounds(int min, int max)";
    string constant Auth = "auth(uint cid, uint deadline, bytes proof)";
    string constant Data = "data(bytes payload)";
    string constant Evm = "evm(bytes payload)";
    string constant Query = "query(bytes payload)";
    string constant Response = "response(bytes payload)";
    string constant Break = "break()";
}

/// @title Forms
/// @notice Reusable structural block schemas for core tuple shapes.
/// These describe payload form without assigning command or query semantics.
library Forms {
    string constant Status = "status(bool ok)";
    string constant AssetAmount = "assetAmount(bytes32 asset, bytes32 meta, uint amount)";
    string constant AccountAsset = "accountAsset(bytes32 account, bytes32 asset, bytes32 meta)";
    string constant AccountAmount = "accountAmount(bytes32 account, bytes32 asset, bytes32 meta, uint amount)";
    string constant HostAmount = "hostAmount(uint host, bytes32 asset, bytes32 meta, uint amount)";
    string constant HostAccountAsset = "hostAccountAsset(uint host, bytes32 account, bytes32 asset, bytes32 meta)";
    string constant HostAccountAmount = "hostAccountAmount(uint host, bytes32 account, bytes32 asset, bytes32 meta, uint amount)";
}

/// @title Sizes
/// @notice Total byte sizes for fixed-width block types, including the 8-byte header (4-byte key + 4-byte payloadLen).
library Sizes {
    /// @dev Shared block header size: 4-byte key + 4-byte payload length.
    uint constant Header = 8;
    /// @dev One fixed-width payload word.
    uint constant Word = 32;
    /// @dev 8 header + 32 payload = 40 bytes total.
    uint constant B32 = Header + Word;
    /// @dev 8 header + 64 payload = 72 bytes total.
    uint constant B64 = Header + 2 * Word;
    /// @dev 8 header + 96 payload = 104 bytes total.
    uint constant B96 = Header + 3 * Word;
    /// @dev 8 header + 128 payload = 136 bytes total.
    uint constant B128 = Header + 4 * Word;
    /// @dev 8 header + 160 payload = 168 bytes total.
    uint constant B160 = Header + 5 * Word;
    /// @dev AUTH proof segment only: 20-byte signer + 65-byte signature = 85 bytes
    uint constant Proof = 85;
    /// @dev AUTH block: 8 header + 32 cid + 32 deadline + 85 proof = 157 bytes
    uint constant Auth = B64 + Proof;
    /// @dev AMOUNT block: 8 header + 32 asset + 32 meta + 32 amount = 104 bytes
    uint constant Amount = B96;
    /// @dev BALANCE block: 8 header + 32 asset + 32 meta + 32 amount = 104 bytes
    uint constant Balance = B96;
    /// @dev BOUNDS block: 8 header + 32 min + 32 max = 72 bytes
    uint constant Bounds = B64;
    /// @dev FEE block: 8 header + 32 amount = 40 bytes
    uint constant Fee = B32;
    /// @dev BOUNTY block: 8 header + 32 amount + 32 relayer = 72 bytes
    uint constant Bounty = B64;
    /// @dev ALLOCATION/CUSTODY block: 8 header + 32 host + 32 asset + 32 meta + 32 amount = 136 bytes
    uint constant HostAmount = B128;
    /// @dev TRANSACTION block: 8 header + 32 from + 32 to + 32 asset + 32 meta + 32 amount = 168 bytes
    uint constant Transaction = B160;
}
