// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Keys} from "./Keys.sol";
import {Sizes, Specs} from "./Specs.sol";
import {max32} from "../utils/Utils.sol";

/// @title Blocks
/// @notice Stateless helpers for inspecting and encoding protocol blocks.
/// @dev Blocks use `[key:4][payload length:4][payload]`. Relative inspection
/// helpers take a calldata region as `offset`, `end`, and relative `i`; they
/// validate that the complete block lies within that region. Absolute helpers
/// take a direct calldata position `abs` and intentionally omit logical-region
/// bounds checks. Their caller must validate the consumed position through a
/// surrounding cursor, execution, or equivalent boundary.
///
/// Fixed-width unpackers return decoded fields only because their following
/// position is statically `abs + Sizes.X`. Dynamic leaf and composite unpackers
/// return absolute `next` last because their encoded size is known only while
/// decoding. Built-in composites use optimized assembly for fixed fields and
/// semantic unpackers for child blocks. Custom schema decoders should favor
/// `expect`, readable calldata slices, semantic child unpackers, and a final
/// equality check proving that the children consume the complete payload.
///
/// Specialized fixed and dynamic writers are unchecked: callers must reserve
/// the complete destination region before calling them. Generic memory writers
/// perform their own capacity checks. Helpers are ordered as inspection,
/// specialized writes, decoding, checked memory writes, and block factories;
/// fixed layouts within a section are ordered from smaller to larger payloads.
library Blocks {
    /// @dev A block header or declared payload exceeds the source region.
    error MalformedBlocks();
    /// @dev A block key or payload size does not match its expected shape.
    error InvalidBlock();
    /// @dev A write exceeded the destination buffer.
    error WriterOverflow();
    /// @dev A fixed-width write received an invalid final-word keep length.
    error InvalidKeep();

    // -------------------------------------------------------------------------
    // Calldata inspection and navigation
    // -------------------------------------------------------------------------

    /// @notice Read and validate a block header within a calldata region.
    function header(uint offset, uint end, uint i) internal pure returns (bytes4 key, uint len) {
        if (i + Sizes.Header > end) revert MalformedBlocks();
        uint abs = offset + i;
        key = bytes4(msg.data[abs:abs + 4]);
        len = uint32(bytes4(msg.data[abs + 4:abs + 8]));
        if (i + Sizes.Header + len > end) revert MalformedBlocks();
    }

    /// @notice Decode a block header at an absolute calldata position.
    /// @dev DANGER: This performs an unchecked calldata read and does not ensure the
    /// complete header or payload lies within a logical calldata region.
    function header(uint abs) internal pure returns (bytes4 key, uint len) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        key = bytes4(uint32(head >> 224));
        len = uint32(head >> 192);
    }

    /// @notice Decode a block header and validate its key at an absolute calldata position.
    /// @dev DANGER: This performs an unchecked calldata read and does not ensure the
    /// complete header or payload lies within a logical calldata region.
    function header(uint abs, bytes4 expected) internal pure returns (uint len) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (uint32(head >> 224) != uint32(expected)) revert InvalidBlock();
        len = uint32(head >> 192);
    }

    /// @notice Return whether `i` identifies a header with `key` in a calldata region.
    function hasAt(uint offset, uint len, uint i, bytes4 key) internal pure returns (bool) {
        if (i > len || Sizes.Header > len - i) return false;
        return bytes4(msg.data[offset + i:offset + i + 4]) == key;
    }

    /// @notice Validate a block and return its payload position and following position.
    function expect(
        uint offset,
        uint limit,
        uint i,
        bytes4 key,
        uint min,
        uint max
    ) internal pure returns (uint abs, uint next) {
        (bytes4 current, uint len) = header(offset, limit, i);
        if (current != key) revert InvalidBlock();
        if (len < min || (max != 0 && len > max)) revert InvalidBlock();
        abs = offset + i + Sizes.Header;
        next = i + Sizes.Header + len;
    }

    /// @notice Validate a block header at an absolute calldata position.
    /// @dev DANGER: This performs an unchecked calldata read and does not ensure `end`
    /// lies within the caller's logical calldata region. Only the key, minimum,
    /// and maximum fields of `spec` are used.
    /// @return i Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function expect(uint abs, uint spec) internal pure returns (uint i, uint end) {
        uint len = header(abs, Specs.key(spec));
        if (!Specs.accepts(spec, len)) revert InvalidBlock();

        i = abs + Sizes.Header;
        end = i + len;
    }

    /// @notice Count consecutive blocks with `key` from `i`.
    function run(uint offset, uint end, uint i, bytes4 key) internal pure returns (uint total, uint next) {
        next = i;
        while (next < end) {
            (bytes4 current, uint len) = header(offset, end, next);
            if (current != key) break;
            next += Sizes.Header + len;

            unchecked {
                ++total;
            }
        }
    }

    /// @notice Find the first block with `key` at or after `i`.
    function find(uint offset, uint end, uint i, bytes4 key) internal pure returns (uint) {
        while (i < end) {
            (bytes4 current, uint len) = header(offset, end, i);
            if (current == key) return i;
            i += Sizes.Header + len;
        }
        return end;
    }

    // Fixed-width block writes

    // One-word payloads

    /// @notice Write an ACCOUNT block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B32` bytes first.
    function writeAccount(bytes memory dst, uint i, bytes32 account) internal pure {
        uint spec = Specs.Account;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), account)
        }
    }

    /// @notice Write an ASSET block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B32` bytes first.
    function writeAsset(bytes memory dst, uint i, bytes32 asset) internal pure {
        uint spec = Specs.Asset;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), asset)
        }
    }

    /// @notice Write a NODE block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B32` bytes first.
    function writeNode(bytes memory dst, uint i, uint node) internal pure {
        uint spec = Specs.Node;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), node)
        }
    }

    /// @notice Write a FEE block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B32` bytes first.
    function writeFee(bytes memory dst, uint i, uint amount) internal pure {
        uint spec = Specs.Fee;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), amount)
        }
    }

    /// @notice Write a STATUS block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B32` bytes first.
    function writeStatus(bytes memory dst, uint i, uint code) internal pure {
        uint spec = Specs.Status;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), code)
        }
    }

    // Two-word payloads

    /// @notice Write an AMOUNT block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B64` bytes first.
    function writeAmount(bytes memory dst, uint i, bytes32 asset, uint amount) internal pure {
        uint spec = Specs.Amount;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), asset)
            mstore(add(p, 0x28), amount)
        }
    }

    /// @notice Write a BALANCE block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B64` bytes first.
    function writeBalance(bytes memory dst, uint i, bytes32 asset, uint amount) internal pure {
        uint spec = Specs.Balance;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), asset)
            mstore(add(p, 0x28), amount)
        }
    }

    /// @notice Write a BOUNTY block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B64` bytes first.
    function writeBounty(bytes memory dst, uint i, uint amount, bytes32 relayer) internal pure {
        uint spec = Specs.Bounty;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), amount)
            mstore(add(p, 0x28), relayer)
        }
    }

    /// @notice Write an ASSET_AMOUNT block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B64` bytes first.
    function writeAssetAmount(bytes memory dst, uint i, bytes32 asset, uint amount) internal pure {
        uint spec = Specs.AssetAmount;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), asset)
            mstore(add(p, 0x28), amount)
        }
    }

    /// @notice Write an ACCOUNT_ASSET block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B64` bytes first.
    function writeAccountAsset(bytes memory dst, uint i, bytes32 account, bytes32 asset) internal pure {
        uint spec = Specs.AccountAsset;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), account)
            mstore(add(p, 0x28), asset)
        }
    }

    // Three-word payloads

    /// @notice Write a BALANCE_LIMIT block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B96` bytes first.
    function writeBalanceLimit(bytes memory dst, uint i, bytes32 asset, uint min, uint max) internal pure {
        uint spec = Specs.BalanceLimit;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), asset)
            mstore(add(p, 0x28), min)
            mstore(add(p, 0x48), max)
        }
    }

    /// @notice Write an ALLOCATION block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B96` bytes first.
    function writeAllocation(bytes memory dst, uint i, uint host, bytes32 asset, uint amount) internal pure {
        uint spec = Specs.Allocation;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), host)
            mstore(add(p, 0x28), asset)
            mstore(add(p, 0x48), amount)
        }
    }

    /// @notice Write an ALLOWANCE block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B96` bytes first.
    function writeAllowance(bytes memory dst, uint i, uint host, bytes32 asset, uint amount) internal pure {
        uint spec = Specs.Allowance;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), host)
            mstore(add(p, 0x28), asset)
            mstore(add(p, 0x48), amount)
        }
    }

    /// @notice Write a CUSTODY block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B96` bytes first.
    function writeCustody(bytes memory dst, uint i, uint host, bytes32 asset, uint amount) internal pure {
        uint spec = Specs.Custody;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), host)
            mstore(add(p, 0x28), asset)
            mstore(add(p, 0x48), amount)
        }
    }

    /// @notice Write an ACCOUNT_AMOUNT block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B96` bytes first.
    function writeAccountAmount(bytes memory dst, uint i, bytes32 account, bytes32 asset, uint amount) internal pure {
        uint spec = Specs.AccountAmount;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), account)
            mstore(add(p, 0x28), asset)
            mstore(add(p, 0x48), amount)
        }
    }

    /// @notice Write a HOST_AMOUNT block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B96` bytes first.
    function writeHostAmount(bytes memory dst, uint i, uint host, bytes32 asset, uint amount) internal pure {
        uint spec = Specs.HostAmount;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), host)
            mstore(add(p, 0x28), asset)
            mstore(add(p, 0x48), amount)
        }
    }

    /// @notice Write a HOST_ACCOUNT_ASSET block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B96` bytes first.
    function writeHostAccountAsset(bytes memory dst, uint i, uint host, bytes32 account, bytes32 asset) internal pure {
        uint spec = Specs.HostAccountAsset;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), host)
            mstore(add(p, 0x28), account)
            mstore(add(p, 0x48), asset)
        }
    }

    // Four-word payloads

    /// @notice Write a CUSTODY_LIMIT block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B128` bytes first.
    function writeCustodyLimit(bytes memory dst, uint i, uint host, bytes32 asset, uint min, uint max) internal pure {
        uint spec = Specs.CustodyLimit;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), host)
            mstore(add(p, 0x28), asset)
            mstore(add(p, 0x48), min)
            mstore(add(p, 0x68), max)
        }
    }

    /// @notice Write a TRANSACTION block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B128` bytes first.
    function writeTransaction(
        bytes memory dst,
        uint i,
        bytes32 from,
        bytes32 to,
        bytes32 asset,
        uint amount
    ) internal pure {
        uint spec = Specs.Transaction;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), from)
            mstore(add(p, 0x28), to)
            mstore(add(p, 0x48), asset)
            mstore(add(p, 0x68), amount)
        }
    }

    /// @notice Write a HOST_ACCOUNT_AMOUNT block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B128` bytes first.
    function writeHostAccountAmount(
        bytes memory dst,
        uint i,
        uint host,
        bytes32 account,
        bytes32 asset,
        uint amount
    ) internal pure {
        uint spec = Specs.HostAccountAmount;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), host)
            mstore(add(p, 0x28), account)
            mstore(add(p, 0x48), asset)
            mstore(add(p, 0x68), amount)
        }
    }

    // Dynamic payloads

    /// @notice Write a LIST block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the payload length fits in uint32.
    function writeList(bytes memory dst, uint i, bytes memory value) internal pure {
        uint len = value.length;
        uint key = uint32(Keys.List);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mcopy(add(p, 0x08), add(value, 0x20), len)
        }
    }

    /// @notice Write an EVM block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the payload length fits in uint32.
    function writeEvm(bytes memory dst, uint i, bytes memory value) internal pure {
        uint len = value.length;
        uint key = uint32(Keys.Evm);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mcopy(add(p, 0x08), add(value, 0x20), len)
        }
    }

    /// @notice Write a BYTES block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the payload length fits in uint32.
    function writeBytes(bytes memory dst, uint i, bytes memory value) internal pure {
        uint len = value.length;
        uint key = uint32(Keys.Bytes);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mcopy(add(p, 0x08), add(value, 0x20), len)
        }
    }

    /// @notice Write a STRING block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the payload length fits in uint32.
    function writeString(bytes memory dst, uint i, string memory value) internal pure {
        uint len = bytes(value).length;
        uint key = uint32(Keys.String);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mcopy(add(p, 0x08), add(value, 0x20), len)
        }
    }

    /// @notice Write a STEP block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    function writeStep(bytes memory dst, uint i, uint target, uint resources, bytes memory request) internal pure {
        uint len = 64 + Sizes.Header + request.length;
        uint key = uint32(Keys.Step);
        uint byteskey = uint32(Keys.Bytes);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mstore(add(p, 0x08), target)
            mstore(add(p, 0x28), resources)

            let q := add(p, 0x48)
            let requestlen := mload(request)
            mstore(q, or(shl(224, byteskey), shl(192, requestlen)))
            mcopy(add(q, 0x08), add(request, 0x20), requestlen)
        }
    }

    /// @notice Write a CALL block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    function writeCall(bytes memory dst, uint i, uint target, uint resources, bytes memory payload) internal pure {
        uint len = 64 + Sizes.Header + payload.length;
        uint key = uint32(Keys.Call);
        uint byteskey = uint32(Keys.Bytes);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mstore(add(p, 0x08), target)
            mstore(add(p, 0x28), resources)

            let q := add(p, 0x48)
            let payloadlen := mload(payload)
            mstore(q, or(shl(224, byteskey), shl(192, payloadlen)))
            mcopy(add(q, 0x08), add(payload, 0x20), payloadlen)
        }
    }

    /// @notice Write a RELAY block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    function writeRelay(bytes memory dst, uint i, uint portal, uint resources, bytes memory request) internal pure {
        uint len = 64 + Sizes.Header + request.length;
        uint key = uint32(Keys.Relay);
        uint byteskey = uint32(Keys.Bytes);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mstore(add(p, 0x08), portal)
            mstore(add(p, 0x28), resources)

            let q := add(p, 0x48)
            let requestlen := mload(request)
            mstore(q, or(shl(224, byteskey), shl(192, requestlen)))
            mcopy(add(q, 0x08), add(request, 0x20), requestlen)
        }
    }

    /// @notice Write a DISPATCH block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    function writeDispatch(bytes memory dst, uint i, uint portal, uint resources, bytes memory payload) internal pure {
        uint len = 64 + Sizes.Header + payload.length;
        uint key = uint32(Keys.Dispatch);
        uint byteskey = uint32(Keys.Bytes);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mstore(add(p, 0x08), portal)
            mstore(add(p, 0x28), resources)

            let q := add(p, 0x48)
            let payloadlen := mload(payload)
            mstore(q, or(shl(224, byteskey), shl(192, payloadlen)))
            mcopy(add(q, 0x08), add(payload, 0x20), payloadlen)
        }
    }

    /// @notice Write a CONTEXT block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    function writeContext(
        bytes memory dst,
        uint i,
        bytes32 account,
        bytes memory state,
        bytes memory request
    ) internal pure {
        uint len = 32 + 2 * Sizes.Header + state.length + request.length;
        uint key = uint32(Keys.Context);
        uint byteskey = uint32(Keys.Bytes);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mstore(add(p, 0x08), account)

            let q := add(p, 0x28)
            let statelen := mload(state)
            mstore(q, or(shl(224, byteskey), shl(192, statelen)))
            mcopy(add(q, 0x08), add(state, 0x20), statelen)

            let r := add(add(q, 0x08), statelen)
            let requestlen := mload(request)
            mstore(r, or(shl(224, byteskey), shl(192, requestlen)))
            mcopy(add(r, 0x08), add(request, 0x20), requestlen)
        }
    }

    /// @notice Write a RECOVER block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    function writeRecover(
        bytes memory dst,
        uint i,
        uint handler,
        uint resources,
        bytes32 recoverykey,
        bytes memory witness
    ) internal pure {
        uint len = 96 + Sizes.Header + witness.length;
        uint key = uint32(Keys.Recover);
        uint byteskey = uint32(Keys.Bytes);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mstore(add(p, 0x08), handler)
            mstore(add(p, 0x28), resources)
            mstore(add(p, 0x48), recoverykey)

            let q := add(p, 0x68)
            let witnesslen := mload(witness)
            mstore(q, or(shl(224, byteskey), shl(192, witnesslen)))
            mcopy(add(q, 0x08), add(witness, 0x20), witnesslen)
        }
    }

    /// @notice Write a LABEL block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    function writeLabel(bytes memory dst, uint i, uint id, bytes32 namespace, string memory name) internal pure {
        uint len = 64 + Sizes.Header + bytes(name).length;
        uint key = uint32(Keys.Label);
        uint stringkey = uint32(Keys.String);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mstore(add(p, 0x08), id)
            mstore(add(p, 0x28), namespace)

            let q := add(p, 0x48)
            let namelen := mload(name)
            mstore(q, or(shl(224, stringkey), shl(192, namelen)))
            mcopy(add(q, 0x08), add(name, 0x20), namelen)
        }
    }

    /// @notice Write a SCHEMA block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    function writeSchema(bytes memory dst, uint i, uint spec, string memory body, bytes32 name) internal pure {
        uint len = 64 + Sizes.Header + bytes(body).length;
        uint key = uint32(Keys.Schema);
        uint stringkey = uint32(Keys.String);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mstore(add(p, 0x08), spec)

            let q := add(p, 0x28)
            let bodylen := mload(body)
            mstore(q, or(shl(224, stringkey), shl(192, bodylen)))
            mcopy(add(q, 0x08), add(body, 0x20), bodylen)
            mstore(add(add(q, 0x08), bodylen), name)
        }
    }

    // -------------------------------------------------------------------------
    // Calldata decoding
    // -------------------------------------------------------------------------

    /// @dev The fixed-width decoders below validate only the block key and
    /// payload length. Callers must ensure the complete block lies within
    /// their logical calldata region.

    // One-word payloads

    function unpackAccount(uint abs) internal pure returns (bytes32 account) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Account >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            account := calldataload(add(abs, 0x08))
        }
    }

    function unpackAsset(uint abs) internal pure returns (bytes32 asset) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Asset >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            asset := calldataload(add(abs, 0x08))
        }
    }

    function unpackNode(uint abs) internal pure returns (uint node) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Node >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            node := calldataload(add(abs, 0x08))
        }
    }

    function unpackFee(uint abs) internal pure returns (uint amount) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Fee >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            amount := calldataload(add(abs, 0x08))
        }
    }

    function unpackStatus(uint abs) internal pure returns (uint code) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Status >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            code := calldataload(add(abs, 0x08))
        }
    }

    // Two-word payloads

    function unpackAmount(uint abs) internal pure returns (bytes32 asset, uint amount) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Amount >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            asset := calldataload(add(abs, 0x08))
            amount := calldataload(add(abs, 0x28))
        }
    }

    function unpackBalance(uint abs) internal pure returns (bytes32 asset, uint amount) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Balance >> 192) revert InvalidBlock();

        assembly ("memory-safe") {
            asset := calldataload(add(abs, 0x08))
            amount := calldataload(add(abs, 0x28))
        }
    }

    function unpackBounty(uint abs) internal pure returns (uint amount, bytes32 relayer) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Bounty >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            amount := calldataload(add(abs, 0x08))
            relayer := calldataload(add(abs, 0x28))
        }
    }

    function unpackAssetAmount(uint abs) internal pure returns (bytes32 asset, uint amount) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.AssetAmount >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            asset := calldataload(add(abs, 0x08))
            amount := calldataload(add(abs, 0x28))
        }
    }

    function unpackAccountAsset(uint abs) internal pure returns (bytes32 account, bytes32 asset) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.AccountAsset >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            account := calldataload(add(abs, 0x08))
            asset := calldataload(add(abs, 0x28))
        }
    }

    // Three-word payloads

    function unpackBalanceLimit(uint abs) internal pure returns (bytes32 asset, uint min, uint max) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.BalanceLimit >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            asset := calldataload(add(abs, 0x08))
            min := calldataload(add(abs, 0x28))
            max := calldataload(add(abs, 0x48))
        }
    }

    function unpackAllocation(uint abs) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Allocation >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            host := calldataload(add(abs, 0x08))
            asset := calldataload(add(abs, 0x28))
            amount := calldataload(add(abs, 0x48))
        }
    }

    function unpackAllowance(uint abs) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Allowance >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            host := calldataload(add(abs, 0x08))
            asset := calldataload(add(abs, 0x28))
            amount := calldataload(add(abs, 0x48))
        }
    }

    function unpackCustody(uint abs) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Custody >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            host := calldataload(add(abs, 0x08))
            asset := calldataload(add(abs, 0x28))
            amount := calldataload(add(abs, 0x48))
        }
    }

    function unpackAccountAmount(uint abs) internal pure returns (bytes32 account, bytes32 asset, uint amount) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.AccountAmount >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            account := calldataload(add(abs, 0x08))
            asset := calldataload(add(abs, 0x28))
            amount := calldataload(add(abs, 0x48))
        }
    }

    function unpackHostAmount(uint abs) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.HostAmount >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            host := calldataload(add(abs, 0x08))
            asset := calldataload(add(abs, 0x28))
            amount := calldataload(add(abs, 0x48))
        }
    }

    function unpackHostAccountAsset(uint abs) internal pure returns (uint host, bytes32 account, bytes32 asset) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.HostAccountAsset >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            host := calldataload(add(abs, 0x08))
            account := calldataload(add(abs, 0x28))
            asset := calldataload(add(abs, 0x48))
        }
    }

    // Four-word payloads

    function unpackCustodyLimit(uint abs) internal pure returns (uint host, bytes32 asset, uint min, uint max) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.CustodyLimit >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            host := calldataload(add(abs, 0x08))
            asset := calldataload(add(abs, 0x28))
            min := calldataload(add(abs, 0x48))
            max := calldataload(add(abs, 0x68))
        }
    }

    function unpackTransaction(uint abs) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, uint amount) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.Transaction >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            from := calldataload(add(abs, 0x08))
            to := calldataload(add(abs, 0x28))
            asset := calldataload(add(abs, 0x48))
            amount := calldataload(add(abs, 0x68))
        }
    }

    function unpackHostAccountAmount(
        uint abs
    ) internal pure returns (uint host, bytes32 account, bytes32 asset, uint amount) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (head >> 192 != Specs.HostAccountAmount >> 192) revert InvalidBlock();
        assembly ("memory-safe") {
            host := calldataload(add(abs, 0x08))
            account := calldataload(add(abs, 0x28))
            asset := calldataload(add(abs, 0x48))
            amount := calldataload(add(abs, 0x68))
        }
    }

    // Dynamic leaf blocks

    function unpackList(uint abs) internal pure returns (bytes calldata value, uint next) {
        return unpackRaw(abs, Keys.List);
    }

    function unpackEvm(uint abs) internal pure returns (bytes calldata value, uint next) {
        return unpackRaw(abs, Keys.Evm);
    }

    function unpackBytes(uint abs) internal pure returns (bytes calldata value, uint next) {
        return unpackRaw(abs, Keys.Bytes);
    }

    function unpackString(uint abs) internal pure returns (bytes calldata value, uint next) {
        return unpackRaw(abs, Keys.String);
    }

    function unpackRaw(uint abs, bytes4 expected) private pure returns (bytes calldata value, uint next) {
        uint len = header(abs, expected);
        assembly ("memory-safe") {
            value.offset := add(abs, 0x08)
            value.length := len
        }
        next = abs + Sizes.Header + len;
    }

    // Composite blocks

    // One fixed word

    function unpackContext(
        uint abs
    ) internal pure returns (bytes32 account, bytes calldata state, bytes calldata request, uint next) {
        (uint i, uint end) = expect(abs, Specs.Context);
        assembly ("memory-safe") {
            account := calldataload(i)
        }
        (state, next) = unpackBytes(i + 32);
        (request, next) = unpackBytes(next);
        if (next != end) revert InvalidBlock();
    }

    // Two fixed words

    function unpackStep(
        uint abs
    ) internal pure returns (uint target, uint resources, bytes calldata request, uint next) {
        (uint i, uint end) = expect(abs, Specs.Step);
        assembly ("memory-safe") {
            target := calldataload(i)
            resources := calldataload(add(i, 0x20))
        }
        (request, next) = unpackBytes(i + 64);
        if (next != end) revert InvalidBlock();
    }

    function unpackCall(
        uint abs
    ) internal pure returns (uint target, uint resources, bytes calldata payload, uint next) {
        (uint i, uint end) = expect(abs, Specs.Call);
        assembly ("memory-safe") {
            target := calldataload(i)
            resources := calldataload(add(i, 0x20))
        }
        (payload, next) = unpackBytes(i + 64);
        if (next != end) revert InvalidBlock();
    }

    function unpackRelay(
        uint abs
    ) internal pure returns (uint portal, uint resources, bytes calldata request, uint next) {
        (uint i, uint end) = expect(abs, Specs.Relay);
        assembly ("memory-safe") {
            portal := calldataload(i)
            resources := calldataload(add(i, 0x20))
        }
        (request, next) = unpackBytes(i + 64);
        if (next != end) revert InvalidBlock();
    }

    function unpackDispatch(
        uint abs
    ) internal pure returns (uint portal, uint resources, bytes calldata payload, uint next) {
        (uint i, uint end) = expect(abs, Specs.Dispatch);
        assembly ("memory-safe") {
            portal := calldataload(i)
            resources := calldataload(add(i, 0x20))
        }
        (payload, next) = unpackBytes(i + 64);
        if (next != end) revert InvalidBlock();
    }

    function unpackLabel(
        uint abs
    ) internal pure returns (uint id, bytes32 namespace, string memory name, uint next) {
        (uint i, uint end) = expect(abs, Specs.Label);
        assembly ("memory-safe") {
            id := calldataload(i)
            namespace := calldataload(add(i, 0x20))
        }
        bytes calldata value;
        (value, next) = unpackString(i + 64);
        if (next != end) revert InvalidBlock();
        name = string(value);
    }

    function unpackSchema(
        uint abs
    ) internal pure returns (uint spec, string memory body, bytes32 name, uint next) {
        (uint i, uint end) = expect(abs, Specs.Schema);
        assembly ("memory-safe") {
            spec := calldataload(i)
        }
        bytes calldata value;
        (value, next) = unpackString(i + 32);
        if (next + 32 != end) revert InvalidBlock();
        assembly ("memory-safe") {
            name := calldataload(next)
        }
        next = end;
        body = string(value);
    }

    // Three fixed words

    function unpackRecover(
        uint abs
    ) internal pure returns (uint handler, uint resources, bytes32 key, bytes calldata witness, uint next) {
        (uint i, uint end) = expect(abs, Specs.Recover);
        assembly ("memory-safe") {
            handler := calldataload(i)
            resources := calldataload(add(i, 0x20))
            key := calldataload(add(i, 0x40))
        }
        (witness, next) = unpackBytes(i + 96);
        if (next != end) revert InvalidBlock();
    }

    // -------------------------------------------------------------------------
    // Memory writes
    // -------------------------------------------------------------------------

    /// @dev Write a block header and return its memory pointer.
    function writeHeader(bytes memory dst, uint i, bytes4 key, uint32 len) private pure returns (uint p) {
        uint word = (uint(uint32(key)) << 224) | (uint(len) << 192);
        assembly ("memory-safe") {
            p := add(add(dst, 0x20), i)
            mstore(p, word)
        }
    }

    /// @notice Write a block with a dynamic payload at byte offset `i`.
    function write(bytes memory dst, uint i, bytes4 key, bytes memory payload) internal pure returns (uint next) {
        next = i + Sizes.Header + payload.length;
        if (next > dst.length) revert WriterOverflow();
        uint p = writeHeader(dst, i, key, uint32(max32(payload.length)));
        assembly ("memory-safe") {
            mcopy(add(p, 0x08), add(payload, 0x20), mload(payload))
        }
    }

    /// @notice Write a block with one payload word, keeping `keep` bytes from that word.
    function write32(bytes memory dst, uint i, bytes4 key, bytes32 a, uint keep) internal pure returns (uint next) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        if (i + Sizes.B32 > dst.length) revert WriterOverflow();
        next = i + Sizes.Header + keep;
        uint p = writeHeader(dst, i, key, uint32(keep));
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
        }
    }

    // -------------------------------------------------------------------------
    // Block factory helpers
    // -------------------------------------------------------------------------

    /// @notice Encode a block with a raw payload.
    /// @param key Block type key.
    /// @param payload Raw payload bytes.
    /// @return Encoded block bytes.
    function create(bytes4 key, bytes memory payload) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(payload.length)), payload);
    }

    /// @notice Encode a BYTES block with a raw payload.
    /// @param value Raw payload bytes.
    /// @return Encoded BYTES block bytes.
    function data(bytes memory value) internal pure returns (bytes memory) {
        return create(Keys.Bytes, value);
    }

    /// @notice Encode a STRING block with a UTF-8 payload.
    /// @param value String payload.
    /// @return Encoded STRING block bytes.
    function text(string memory value) internal pure returns (bytes memory) {
        return create(Keys.String, bytes(value));
    }

    /// @notice Encode a BOUNTY block.
    /// @param amount Relayer reward amount.
    /// @param relayer Relayer account identifier.
    /// @return Encoded BOUNTY block bytes.
    function bounty(uint amount, bytes32 relayer) internal pure returns (bytes memory) {
        return bytes.concat(Keys.Bounty, bytes4(uint32(64)), bytes32(amount), relayer);
    }

    /// @notice Encode a BALANCE block.
    /// @param asset Asset identifier.
    /// @param amount Token amount.
    /// @return Encoded BALANCE block bytes.
    function balance(bytes32 asset, uint amount) internal pure returns (bytes memory) {
        return bytes.concat(Keys.Balance, bytes4(uint32(64)), asset, bytes32(amount));
    }

    /// @notice Encode a CUSTODY block.
    /// @param host Host node ID holding the custody.
    /// @param asset Asset identifier.
    /// @param amount Token amount.
    /// @return Encoded CUSTODY block bytes.
    function custody(uint host, bytes32 asset, uint amount) internal pure returns (bytes memory) {
        return bytes.concat(Keys.Custody, bytes4(uint32(96)), bytes32(host), asset, bytes32(amount));
    }

    /// @notice Encode a TRANSACTION block.
    /// @param from Source account identifier.
    /// @param to Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Transfer amount.
    /// @return Encoded TRANSACTION block bytes.
    function transaction(bytes32 from, bytes32 to, bytes32 asset, uint amount) internal pure returns (bytes memory) {
        return bytes.concat(Keys.Transaction, bytes4(uint32(128)), from, to, asset, bytes32(amount));
    }

    /// @notice Encode a STEP block.
    /// @param target Command target identifier.
    /// @param resources Packed resources assigned to the step.
    /// @param request Raw nested request payload.
    /// @return Encoded STEP block bytes.
    function step(uint target, uint resources, bytes memory request) internal pure returns (bytes memory) {
        return create(Keys.Step, bytes.concat(bytes32(target), bytes32(resources), data(request)));
    }

    /// @notice Encode a CALL block.
    /// @param target Target node identifier.
    /// @param resources Packed resources assigned to the call.
    /// @param payload Raw calldata payload for the target.
    /// @return Encoded CALL block bytes.
    function call(uint target, uint resources, bytes memory payload) internal pure returns (bytes memory) {
        return create(Keys.Call, bytes.concat(bytes32(target), bytes32(resources), data(payload)));
    }

    /// @notice Encode a CONTEXT block.
    /// @param account Command account identifier.
    /// @param state Embedded state block stream.
    /// @param request Embedded request block stream.
    /// @return Encoded CONTEXT block bytes.
    function context(bytes32 account, bytes memory state, bytes memory request) internal pure returns (bytes memory) {
        return create(Keys.Context, bytes.concat(account, data(state), data(request)));
    }

    /// @notice Encode a RELAY block.
    /// @param portal Destination portal identifier, often the destination host ID.
    /// @param resources Chain-specific resources for the destination context.
    /// @param request Nested request block stream.
    /// @return Encoded RELAY block bytes.
    function relay(uint portal, uint resources, bytes memory request) internal pure returns (bytes memory) {
        return create(Keys.Relay, bytes.concat(bytes32(portal), bytes32(resources), data(request)));
    }

    /// @notice Encode a DISPATCH block.
    /// @param portal Destination portal identifier, often the destination host ID.
    /// @param resources Chain-specific resources for the destination dispatch.
    /// @param payload Encoded payload.
    /// @return Encoded DISPATCH block bytes.
    function dispatch(uint portal, uint resources, bytes memory payload) internal pure returns (bytes memory) {
        return create(Keys.Dispatch, bytes.concat(bytes32(portal), bytes32(resources), data(payload)));
    }
}
