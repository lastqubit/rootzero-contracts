// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Keys} from "./Keys.sol";
import {Sizes, Specs} from "./Specs.sol";
import {max32} from "../utils/Utils.sol";

/// @title Blocks
/// @notice Stateless helpers for inspecting and encoding protocol blocks.
/// @dev Blocks use `[key:4][payload length:4][payload]`. Calldata helpers use
/// absolute positions. Bounded navigation helpers also take an absolute `end`;
/// specialized absolute readers and unpackers intentionally omit logical-region
/// checks. Their caller must validate consumed positions through a surrounding
/// cursor, execution, or equivalent boundary.
///
/// Fixed-width unpackers return decoded fields only because their following
/// position is statically `abs + Sizes.X`. Dynamic leaf and composite unpackers
/// return absolute `end` last because their encoded size is known only while
/// decoding. Built-in composites use optimized assembly for fixed fields and
/// semantic unpackers for child blocks. Custom schema decoders should favor
/// `expect`, readable calldata slices, semantic child unpackers, and a final
/// equality check proving that the children consume the complete payload.
///
/// Generic and specialized writers are unchecked: callers must validate inputs
/// and reserve the complete destination region before calling them. Helpers are
/// ordered as inspection, generic writes, specialized writes, decoding, and
/// block factories; fixed layouts within a section are ordered from smaller to
/// larger payloads.
library Blocks {
    /// @dev A block header or declared payload exceeds the source region.
    error MalformedBlocks();
    /// @dev A block key or payload size does not match its expected shape.
    error InvalidBlock();
    /// @dev A decoded value did not match the expected value.
    error UnexpectedValue();
    /// @dev A scoped block run contained no blocks.
    error EmptyRun();
    /// @dev A block run was scoped with a zero stride.
    error ZeroStride();
    /// @dev A block count is not divisible by its declared stride.
    error BadRatio();

    // -------------------------------------------------------------------------
    // Calldata inspection and navigation
    // -------------------------------------------------------------------------

    /// @notice Decode a block header at an absolute calldata position.
    /// @dev DANGER: This performs an unchecked calldata read and does not ensure the
    /// complete header or payload lies within a logical calldata region.
    /// @param abs Absolute calldata position of the header.
    /// @return key Decoded block key.
    /// @return len Decoded payload length.
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
    /// @param abs Absolute calldata position of the header.
    /// @param expected Expected block key.
    /// @return len Decoded payload length.
    function header(uint abs, bytes4 expected) internal pure returns (uint len) {
        uint head;
        assembly ("memory-safe") {
            head := calldataload(abs)
        }
        if (uint32(head >> 224) != uint32(expected)) revert InvalidBlock();
        len = uint32(head >> 192);
    }

    /// @notice Validate a block header at an absolute calldata position.
    /// @dev DANGER: This performs an unchecked calldata read and does not ensure `end`
    /// lies within the caller's logical calldata region. Only the key, minimum,
    /// and maximum fields of `spec` are used.
    /// @param abs Absolute calldata position of the header.
    /// @param spec Expected block specification.
    /// @return body Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function expect(uint abs, uint spec) internal pure returns (uint body, uint end) {
        uint len = header(abs, Specs.key(spec));
        if (!Specs.accepts(spec, len)) revert InvalidBlock();

        body = abs + Sizes.Header;
        end = body + len;
    }

    /// @dev Validate the key and exact payload size of a fixed-width block.
    /// @param abs Absolute calldata position of the header.
    /// @param spec Expected block specification.
    /// @param size Expected payload length.
    /// @return body Absolute position of the payload.
    /// @return end Absolute position after the payload.
    function expectFixed(uint abs, uint spec, uint size) private pure returns (uint body, uint end) {
        if (header(abs, Specs.key(spec)) != size) revert InvalidBlock();
        body = abs + Sizes.Header;
        end = body + size;
    }

    /// @notice Return whether `abs` identifies a header with `key` before an absolute end.
    /// @param abs Absolute calldata position to inspect.
    /// @param end Absolute region boundary.
    /// @param key Expected block key.
    /// @return Whether a complete matching header exists.
    function hasAt(uint abs, uint end, bytes4 key) internal pure returns (bool) {
        if (abs > end || Sizes.Header > end - abs) return false;
        return bytes4(read32(abs)) == key;
    }

    /// @notice Find the first block with `key` at or after absolute position `abs`.
    /// @param abs Absolute search position.
    /// @param end Absolute region boundary.
    /// @param key Block key to find.
    /// @return Absolute position of the matching block, or `end` when absent.
    function find(uint abs, uint end, bytes4 key) internal pure returns (uint) {
        while (abs < end) {
            (bytes4 current, uint len) = header(abs);
            if (Sizes.Header + len > end - abs) revert MalformedBlocks();
            if (current == key) return abs;
            abs += Sizes.Header + len;
        }
        return end;
    }

    /// @notice Count consecutive blocks with `key` from absolute position `abs`.
    /// @param abs Absolute start position.
    /// @param limit Absolute region boundary.
    /// @param key Block key forming the run.
    /// @return total Number of consecutive matching blocks.
    /// @return end Absolute position after the run.
    function run(uint abs, uint limit, bytes4 key) internal pure returns (uint total, uint end) {
        end = abs;
        while (end < limit) {
            (bytes4 current, uint len) = header(end);
            if (Sizes.Header + len > limit - end) revert MalformedBlocks();
            if (current != key) break;
            end += Sizes.Header + len;

            unchecked {
                ++total;
            }
        }
    }

    /// @notice Scope a consecutive block run into equal-sized groups.
    /// @param abs Absolute start position.
    /// @param limit Absolute region boundary.
    /// @param key Block key forming the run.
    /// @param stride Number of blocks per group.
    /// @return groups Number of complete groups in the run.
    /// @return end Absolute position immediately after the run.
    function scope(
        uint abs,
        uint limit,
        bytes4 key,
        uint stride
    ) internal pure returns (uint groups, uint end) {
        if (stride == 0) revert ZeroStride();
        uint count;
        (count, end) = run(abs, limit, key);
        if (count == 0) revert EmptyRun();
        if (count % stride != 0) revert BadRatio();
        groups = count / stride;
    }

    // Generic block writes

    /// @notice Write a custom block with one payload word at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B32` bytes first.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param key Block key.
    /// @param a Payload word.
    function write32(bytes memory dst, uint i, bytes4 key, bytes32 a) internal pure {
        uint head = (uint(uint32(key)) << 224) | (uint(32) << 192);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, head)
            mstore(add(p, 0x08), a)
        }
    }

    /// @notice Write a custom block with two payload words at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B64` bytes first.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param key Block key.
    /// @param a First payload word.
    /// @param b Second payload word.
    function write64(bytes memory dst, uint i, bytes4 key, bytes32 a, bytes32 b) internal pure {
        uint head = (uint(uint32(key)) << 224) | (uint(64) << 192);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, head)
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
        }
    }

    /// @notice Write a custom block with three payload words at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B96` bytes first.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param key Block key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    function write96(bytes memory dst, uint i, bytes4 key, bytes32 a, bytes32 b, bytes32 c) internal pure {
        uint head = (uint(uint32(key)) << 224) | (uint(96) << 192);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, head)
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
            mstore(add(p, 0x48), c)
        }
    }

    /// @notice Write a custom block with a dynamic payload at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must validate the payload
    /// length and reserve `Sizes.Header + payload.length` bytes first.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param key Block key.
    /// @param payload Block payload.
    function write(bytes memory dst, uint i, bytes4 key, bytes memory payload) internal pure {
        uint len = max32(payload.length);
        uint head = (uint(uint32(key)) << 224) | (len << 192);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, head)
            mcopy(add(p, 0x08), add(payload, 0x20), len)
        }
    }

    // Fixed-width block writes

    // One-word payloads

    /// @notice Write an ACCOUNT block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B32` bytes first.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param account Account identifier to encode.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param asset Asset identifier to encode.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param node Node identifier to encode.
    function writeNode(bytes memory dst, uint i, uint node) internal pure {
        uint spec = Specs.Node;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), node)
        }
    }

    /// @notice Write a STATUS block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B32` bytes first.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param code Status code to encode.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param asset Asset identifier to encode.
    /// @param amount Asset amount to encode.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param asset Asset identifier to encode.
    /// @param amount Balance amount to encode.
    function writeBalance(bytes memory dst, uint i, bytes32 asset, uint amount) internal pure {
        uint spec = Specs.Balance;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), asset)
            mstore(add(p, 0x28), amount)
        }
    }

    /// @notice Write an ACCOUNT_ASSET block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B64` bytes first.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param account Account identifier to encode.
    /// @param asset Asset identifier to encode.
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

    /// @notice Write an ALLOCATION block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B96` bytes first.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param host Host identifier to encode.
    /// @param asset Asset identifier to encode.
    /// @param amount Allocation amount to encode.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param host Host identifier to encode.
    /// @param asset Asset identifier to encode.
    /// @param amount Allowance amount to encode.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param host Host identifier to encode.
    /// @param asset Asset identifier to encode.
    /// @param amount Custody amount to encode.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param account Account identifier to encode.
    /// @param asset Asset identifier to encode.
    /// @param amount Account amount to encode.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param host Host identifier to encode.
    /// @param asset Asset identifier to encode.
    /// @param amount Host amount to encode.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param host Host identifier to encode.
    /// @param account Account identifier to encode.
    /// @param asset Asset identifier to encode.
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

    /// @notice Write a TRANSACTION block at `i`.
    /// @dev DANGER: Unchecked memory write. Reserve `Sizes.B128` bytes first.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param from Debit account identifier.
    /// @param to Credit account identifier.
    /// @param asset Asset identifier.
    /// @param amount Transaction amount.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param host Host identifier.
    /// @param account Account identifier.
    /// @param asset Asset identifier.
    /// @param amount Host account amount.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param value Encoded list payload.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param value EVM payload.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param value Byte payload.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param value String payload.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param cmd Command identifier.
    /// @param resources Packed resources.
    /// @param input Command input.
    function writeStep(bytes memory dst, uint i, uint cmd, uint resources, bytes memory input) internal pure {
        uint len = 64 + Sizes.Header + input.length;
        uint key = uint32(Keys.Step);
        uint byteskey = uint32(Keys.Bytes);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mstore(add(p, 0x08), cmd)
            mstore(add(p, 0x28), resources)

            let q := add(p, 0x48)
            let inputlen := mload(input)
            mstore(q, or(shl(224, byteskey), shl(192, inputlen)))
            mcopy(add(q, 0x08), add(input, 0x20), inputlen)
        }
    }

    /// @notice Write a CALL block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param target Call target.
    /// @param resources Packed resources.
    /// @param payload Call payload.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param portal Destination portal.
    /// @param resources Packed resources.
    /// @param input Relay input.
    function writeRelay(bytes memory dst, uint i, uint portal, uint resources, bytes memory input) internal pure {
        uint len = 64 + Sizes.Header + input.length;
        uint key = uint32(Keys.Relay);
        uint byteskey = uint32(Keys.Bytes);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mstore(add(p, 0x08), portal)
            mstore(add(p, 0x28), resources)

            let q := add(p, 0x48)
            let inputlen := mload(input)
            mstore(q, or(shl(224, byteskey), shl(192, inputlen)))
            mcopy(add(q, 0x08), add(input, 0x20), inputlen)
        }
    }

    /// @notice Write a DISPATCH block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param portal Destination portal.
    /// @param resources Packed resources.
    /// @param payload Dispatch payload.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param account Account identifier.
    /// @param state State payload.
    /// @param input Input payload.
    function writeContext(
        bytes memory dst,
        uint i,
        bytes32 account,
        bytes memory state,
        bytes memory input
    ) internal pure {
        uint len = 32 + 2 * Sizes.Header + state.length + input.length;
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
            let inputlen := mload(input)
            mstore(r, or(shl(224, byteskey), shl(192, inputlen)))
            mcopy(add(r, 0x08), add(input, 0x20), inputlen)
        }
    }

    /// @notice Write a RECOVER block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param handler Recovery handler.
    /// @param resources Packed resources.
    /// @param recoverykey Recovery key.
    /// @param witness Recovery witness.
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
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param namespace Label namespace.
    /// @param name Label text.
    function writeLabel(bytes memory dst, uint i, bytes32 namespace, string memory name) internal pure {
        uint len = 32 + Sizes.Header + bytes(name).length;
        uint key = uint32(Keys.Label);
        uint stringkey = uint32(Keys.String);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, or(shl(224, key), shl(192, len)))
            mstore(add(p, 0x08), namespace)

            let q := add(p, 0x28)
            let namelen := mload(name)
            mstore(q, or(shl(224, stringkey), shl(192, namelen)))
            mcopy(add(q, 0x08), add(name, 0x20), namelen)
        }
    }

    /// @notice Write a SCHEMA block at `i`.
    /// @dev DANGER: Unchecked memory write. The caller must reserve the complete
    /// block size and ensure the encoded payload length fits in uint32.
    /// @param dst Destination buffer.
    /// @param i Relative write position.
    /// @param spec Block specification.
    /// @param body Schema body.
    /// @param name Schema name.
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

    // Raw reads

    /// @notice Read four bytes from an absolute calldata position.
    /// @dev DANGER: Unchecked calldata read. Values beyond calldata are zero-padded.
    /// @param abs Absolute calldata position.
    /// @return value Decoded four-byte value.
    function read4(uint abs) internal pure returns (bytes4 value) {
        assembly ("memory-safe") {
            value := calldataload(abs)
        }
    }

    /// @notice Read one word from an absolute calldata position.
    /// @dev DANGER: Unchecked calldata read. Values beyond calldata are zero-padded.
    /// @param abs Absolute calldata position.
    /// @return value Decoded word.
    function read32(uint abs) internal pure returns (bytes32 value) {
        assembly ("memory-safe") {
            value := calldataload(abs)
        }
    }

    /// @notice Require the word at an absolute calldata position to match `expected`.
    /// @dev DANGER: Unchecked calldata read. Values beyond calldata are zero-padded.
    /// @param abs Absolute calldata position.
    /// @param expected Expected word.
    function require32(uint abs, bytes32 expected) internal pure {
        if (read32(abs) != expected) revert UnexpectedValue();
    }

    /// @notice Read one unsigned integer from an absolute calldata position.
    /// @dev DANGER: Unchecked calldata read. Values beyond calldata are zero-padded.
    /// @param abs Absolute calldata position.
    /// @return value Decoded unsigned integer.
    function readUint(uint abs) internal pure returns (uint value) {
        assembly ("memory-safe") {
            value := calldataload(abs)
        }
    }

    // Generic block unpackers

    /// @notice Validate a block against `spec` and return its payload.
    /// @param abs Absolute block position.
    /// @param spec Expected block specification.
    /// @return value Decoded payload.
    /// @return end Absolute position after the block.
    function unpackRaw(uint abs, uint spec) internal pure returns (bytes calldata value, uint end) {
        (abs, end) = expect(abs, spec);
        value = msg.data[abs:end];
    }

    /// @notice Decode a spec-validated one-word block at `abs`.
    /// @param abs Absolute block position.
    /// @param spec Expected block specification.
    /// @return a First payload word.
    /// @return end Absolute position after the block.
    function unpack32(uint abs, uint spec) internal pure returns (bytes32 a, uint end) {
        (abs, end) = expectFixed(abs, spec, 32);
        a = read32(abs);
    }

    /// @notice Decode a spec-validated two-word block at `abs`.
    /// @param abs Absolute block position.
    /// @param spec Expected block specification.
    /// @return a First payload word.
    /// @return b Second payload word.
    /// @return end Absolute position after the block.
    function unpack64(uint abs, uint spec) internal pure returns (bytes32 a, bytes32 b, uint end) {
        (abs, end) = expectFixed(abs, spec, 64);
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
        }
    }

    /// @notice Decode a spec-validated three-word block at `abs`.
    /// @param abs Absolute block position.
    /// @param spec Expected block specification.
    /// @return a First payload word.
    /// @return b Second payload word.
    /// @return c Third payload word.
    /// @return end Absolute position after the block.
    function unpack96(
        uint abs,
        uint spec
    ) internal pure returns (bytes32 a, bytes32 b, bytes32 c, uint end) {
        (abs, end) = expectFixed(abs, spec, 96);
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
            c := calldataload(add(abs, 0x40))
        }
    }

    /// @notice Decode a spec-validated four-word block at `abs`.
    /// @param abs Absolute block position.
    /// @param spec Expected block specification.
    /// @return a First payload word.
    /// @return b Second payload word.
    /// @return c Third payload word.
    /// @return d Fourth payload word.
    /// @return end Absolute position after the block.
    function unpack128(
        uint abs,
        uint spec
    ) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d, uint end) {
        (abs, end) = expectFixed(abs, spec, 128);
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
            c := calldataload(add(abs, 0x40))
            d := calldataload(add(abs, 0x60))
        }
    }

    /// @notice Decode a spec-validated five-word block at `abs`.
    /// @param abs Absolute block position.
    /// @param spec Expected block specification.
    /// @return a First payload word.
    /// @return b Second payload word.
    /// @return c Third payload word.
    /// @return d Fourth payload word.
    /// @return e Fifth payload word.
    /// @return end Absolute position after the block.
    function unpack160(
        uint abs,
        uint spec
    ) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e, uint end) {
        (abs, end) = expectFixed(abs, spec, 160);
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
            c := calldataload(add(abs, 0x40))
            d := calldataload(add(abs, 0x60))
            e := calldataload(add(abs, 0x80))
        }
    }

    /// @notice Decode a spec-validated asset and amount pair.
    /// @param abs Absolute block position.
    /// @param spec Expected block specification.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
    /// @return end Absolute position after the block.
    function unpackAssetAmount(
        uint abs,
        uint spec
    ) internal pure returns (bytes32 asset, uint amount, uint end) {
        bytes32 value;
        (asset, value, end) = unpack64(abs, spec);
        amount = uint(value);
    }

    /// @notice Decode a spec-validated account, asset, and amount tuple.
    /// @param abs Absolute block position.
    /// @param spec Expected block specification.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
    /// @return end Absolute position after the block.
    function unpackAccountAmount(
        uint abs,
        uint spec
    ) internal pure returns (bytes32 account, bytes32 asset, uint amount, uint end) {
        bytes32 value;
        (account, asset, value, end) = unpack96(abs, spec);
        amount = uint(value);
    }

    /// @notice Decode a spec-validated host, asset, and amount tuple.
    /// @param abs Absolute block position.
    /// @param spec Expected block specification.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
    /// @return end Absolute position after the block.
    function unpackHostAmount(
        uint abs,
        uint spec
    ) internal pure returns (uint host, bytes32 asset, uint amount, uint end) {
        bytes32 value;
        bytes32 raw;
        (raw, asset, value, end) = unpack96(abs, spec);
        host = uint(raw);
        amount = uint(value);
    }

    /// @notice Decode a spec-validated host, account, and asset tuple.
    /// @param abs Absolute block position.
    /// @param spec Expected block specification.
    /// @return host Decoded host identifier.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    /// @return end Absolute position after the block.
    function unpackHostAccountAsset(
        uint abs,
        uint spec
    ) internal pure returns (uint host, bytes32 account, bytes32 asset, uint end) {
        bytes32 raw;
        (raw, account, asset, end) = unpack96(abs, spec);
        host = uint(raw);
    }

    /// @notice Decode a spec-validated transaction tuple.
    /// @param abs Absolute block position.
    /// @param spec Expected block specification.
    /// @return from Decoded debit account.
    /// @return to Decoded credit account.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded transaction amount.
    /// @return end Absolute position after the block.
    function unpackTransaction(
        uint abs,
        uint spec
    ) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, uint amount, uint end) {
        bytes32 value;
        (from, to, asset, value, end) = unpack128(abs, spec);
        amount = uint(value);
    }

    // Fixed-width block unpackers

    /// @dev The fixed-width decoders below validate only the block key and
    /// payload length. Callers must ensure the complete block lies within
    /// their logical calldata region.

    // One-word payloads

    /// @notice Decode a low-level fixed-width ACCOUNT block at `abs`.
    /// @param abs Absolute block position.
    /// @return account Decoded account identifier.
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

    /// @notice Decode a low-level fixed-width ASSET block at `abs`.
    /// @param abs Absolute block position.
    /// @return asset Decoded asset identifier.
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

    /// @notice Decode a low-level fixed-width NODE block at `abs`.
    /// @param abs Absolute block position.
    /// @return node Decoded node identifier.
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

    /// @notice Decode a low-level fixed-width STATUS block at `abs`.
    /// @param abs Absolute block position.
    /// @return code Decoded status code.
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

    /// @notice Decode a low-level fixed-width AMOUNT block at `abs`.
    /// @param abs Absolute block position.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
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

    /// @notice Decode a low-level fixed-width BALANCE block at `abs`.
    /// @param abs Absolute block position.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded balance.
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

    /// @notice Decode a low-level fixed-width ACCOUNT_ASSET block at `abs`.
    /// @param abs Absolute block position.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
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

    /// @notice Decode a low-level fixed-width ALLOCATION block at `abs`.
    /// @param abs Absolute block position.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded allocation.
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

    /// @notice Decode a low-level fixed-width ALLOWANCE block at `abs`.
    /// @param abs Absolute block position.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded allowance.
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

    /// @notice Decode a low-level fixed-width CUSTODY block at `abs`.
    /// @param abs Absolute block position.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded custody amount.
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

    /// @notice Decode a low-level fixed-width ACCOUNT_AMOUNT block at `abs`.
    /// @param abs Absolute block position.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
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

    /// @notice Decode a low-level fixed-width HOST_AMOUNT block at `abs`.
    /// @param abs Absolute block position.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
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

    /// @notice Decode a low-level fixed-width HOST_ACCOUNT_ASSET block at `abs`.
    /// @param abs Absolute block position.
    /// @return host Decoded host identifier.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
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

    /// @notice Decode a low-level fixed-width TRANSACTION block at `abs`.
    /// @param abs Absolute block position.
    /// @return from Decoded debit account.
    /// @return to Decoded credit account.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded transaction amount.
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

    /// @notice Decode a low-level fixed-width HOST_ACCOUNT_AMOUNT block at `abs`.
    /// @param abs Absolute block position.
    /// @return host Decoded host identifier.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
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

    /// @notice Decode one LIST payload and its absolute end position.
    /// @param abs Absolute block position.
    /// @return value Decoded list payload.
    /// @return end Absolute position after the block.
    function unpackList(uint abs) internal pure returns (bytes calldata value, uint end) {
        return unpackRaw(abs, Keys.List);
    }

    /// @notice Decode one EVM payload and its absolute end position.
    /// @param abs Absolute block position.
    /// @return value Decoded EVM payload.
    /// @return end Absolute position after the block.
    function unpackEvm(uint abs) internal pure returns (bytes calldata value, uint end) {
        return unpackRaw(abs, Keys.Evm);
    }

    /// @notice Decode one BYTES payload and its absolute end position.
    /// @param abs Absolute block position.
    /// @return value Decoded byte payload.
    /// @return end Absolute position after the block.
    function unpackBytes(uint abs) internal pure returns (bytes calldata value, uint end) {
        return unpackRaw(abs, Keys.Bytes);
    }

    /// @notice Decode one STRING payload and its absolute end position.
    /// @param abs Absolute block position.
    /// @return value Decoded string bytes.
    /// @return end Absolute position after the block.
    function unpackString(uint abs) internal pure returns (bytes calldata value, uint end) {
        return unpackRaw(abs, Keys.String);
    }

    /// @dev Decode a dynamic leaf block after validating its key.
    /// @param abs Absolute block position.
    /// @param expected Expected block key.
    /// @return value Decoded payload.
    /// @return end Absolute position after the block.
    function unpackRaw(uint abs, bytes4 expected) private pure returns (bytes calldata value, uint end) {
        uint len = header(abs, expected);
        assembly ("memory-safe") {
            value.offset := add(abs, 0x08)
            value.length := len
        }
        end = abs + Sizes.Header + len;
    }

    // Composite blocks

    // One fixed word

    /// @notice Decode one ANNOTATION block and its nested block stream.
    /// @param abs Absolute block position.
    /// @return entity Decoded entity identifier.
    /// @return stream Decoded annotation block stream.
    /// @return end Absolute position after the block.
    function unpackAnnotation(
        uint abs
    ) internal pure returns (uint entity, bytes calldata stream, uint end) {
        uint limit;
        (abs, limit) = expect(abs, Specs.Annotation);
        assembly ("memory-safe") {
            entity := calldataload(abs)
        }
        (stream, end) = unpackBytes(abs + 32);
        if (end != limit) revert InvalidBlock();
    }

    /// @notice Decode one CONTEXT block and all nested byte blocks.
    /// @param abs Absolute block position.
    /// @return account Decoded account identifier.
    /// @return state Decoded state payload.
    /// @return input Decoded input payload.
    /// @return end Absolute position after the block.
    function unpackContext(
        uint abs
    ) internal pure returns (bytes32 account, bytes calldata state, bytes calldata input, uint end) {
        uint limit;
        (abs, limit) = expect(abs, Specs.Context);
        assembly ("memory-safe") {
            account := calldataload(abs)
        }
        (state, end) = unpackBytes(abs + 32);
        (input, end) = unpackBytes(end);
        if (end != limit) revert InvalidBlock();
    }

    // Two fixed words

    /// @notice Decode one STEP block and its nested input.
    /// @param abs Absolute block position.
    /// @return cmd Decoded command identifier.
    /// @return resources Decoded packed resources.
    /// @return input Decoded command input.
    /// @return end Absolute position after the block.
    function unpackStep(
        uint abs
    ) internal pure returns (uint cmd, uint resources, bytes calldata input, uint end) {
        uint limit;
        (abs, limit) = expect(abs, Specs.Step);
        assembly ("memory-safe") {
            cmd := calldataload(abs)
            resources := calldataload(add(abs, 0x20))
        }
        (input, end) = unpackBytes(abs + 64);
        if (end != limit) revert InvalidBlock();
    }

    /// @notice Decode one CALL block and its nested payload.
    /// @param abs Absolute block position.
    /// @return target Decoded call target.
    /// @return resources Decoded packed resources.
    /// @return payload Decoded call payload.
    /// @return end Absolute position after the block.
    function unpackCall(
        uint abs
    ) internal pure returns (uint target, uint resources, bytes calldata payload, uint end) {
        uint limit;
        (abs, limit) = expect(abs, Specs.Call);
        assembly ("memory-safe") {
            target := calldataload(abs)
            resources := calldataload(add(abs, 0x20))
        }
        (payload, end) = unpackBytes(abs + 64);
        if (end != limit) revert InvalidBlock();
    }

    /// @notice Decode one RELAY block and its nested input.
    /// @param abs Absolute block position.
    /// @return portal Decoded destination portal.
    /// @return resources Decoded packed resources.
    /// @return input Decoded relay input.
    /// @return end Absolute position after the block.
    function unpackRelay(
        uint abs
    ) internal pure returns (uint portal, uint resources, bytes calldata input, uint end) {
        uint limit;
        (abs, limit) = expect(abs, Specs.Relay);
        assembly ("memory-safe") {
            portal := calldataload(abs)
            resources := calldataload(add(abs, 0x20))
        }
        (input, end) = unpackBytes(abs + 64);
        if (end != limit) revert InvalidBlock();
    }

    /// @notice Decode one DISPATCH block and its nested payload.
    /// @param abs Absolute block position.
    /// @return portal Decoded destination portal.
    /// @return resources Decoded packed resources.
    /// @return payload Decoded dispatch payload.
    /// @return end Absolute position after the block.
    function unpackDispatch(
        uint abs
    ) internal pure returns (uint portal, uint resources, bytes calldata payload, uint end) {
        uint limit;
        (abs, limit) = expect(abs, Specs.Dispatch);
        assembly ("memory-safe") {
            portal := calldataload(abs)
            resources := calldataload(add(abs, 0x20))
        }
        (payload, end) = unpackBytes(abs + 64);
        if (end != limit) revert InvalidBlock();
    }

    /// @notice Decode one LABEL block and its nested name.
    /// @param abs Absolute block position.
    /// @return namespace Decoded label namespace.
    /// @return name Decoded label text.
    /// @return end Absolute position after the block.
    function unpackLabel(uint abs) internal pure returns (bytes32 namespace, string memory name, uint end) {
        uint limit;
        (abs, limit) = expect(abs, Specs.Label);
        assembly ("memory-safe") {
            namespace := calldataload(abs)
        }
        bytes calldata value;
        (value, end) = unpackString(abs + 32);
        if (end != limit) revert InvalidBlock();
        name = string(value);
    }

    /// @notice Decode one SCHEMA block and its nested body.
    /// @param abs Absolute block position.
    /// @return spec Decoded block specification.
    /// @return body Decoded schema body.
    /// @return name Decoded schema name.
    /// @return end Absolute position after the block.
    function unpackSchema(uint abs) internal pure returns (uint spec, string memory body, bytes32 name, uint end) {
        uint limit;
        (abs, limit) = expect(abs, Specs.Schema);
        assembly ("memory-safe") {
            spec := calldataload(abs)
        }
        bytes calldata value;
        (value, end) = unpackString(abs + 32);
        if (end + 32 != limit) revert InvalidBlock();
        assembly ("memory-safe") {
            name := calldataload(end)
        }
        end = limit;
        body = string(value);
    }

    // Three fixed words

    /// @notice Decode one RECOVER block and its nested witness.
    /// @param abs Absolute block position.
    /// @return handler Decoded recovery handler.
    /// @return resources Decoded packed resources.
    /// @return key Decoded recovery key.
    /// @return witness Decoded recovery witness.
    /// @return end Absolute position after the block.
    function unpackRecover(
        uint abs
    ) internal pure returns (uint handler, uint resources, bytes32 key, bytes calldata witness, uint end) {
        uint limit;
        (abs, limit) = expect(abs, Specs.Recover);
        assembly ("memory-safe") {
            handler := calldataload(abs)
            resources := calldataload(add(abs, 0x20))
            key := calldataload(add(abs, 0x40))
        }
        (witness, end) = unpackBytes(abs + 96);
        if (end != limit) revert InvalidBlock();
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

    /// @notice Encode a LABEL block.
    /// @param namespace Label namespace.
    /// @param name Label text.
    /// @return Encoded LABEL block bytes.
    function label(bytes32 namespace, string memory name) internal pure returns (bytes memory) {
        return create(Keys.Label, bytes.concat(namespace, text(name)));
    }

    /// @notice Encode an ACTION annotation block.
    /// @param value Canonical semantic action identifier.
    /// @return Encoded ACTION block bytes.
    function action(uint value) internal pure returns (bytes memory) {
        return create(Keys.Action, bytes.concat(bytes32(value)));
    }

    /// @notice Encode a SCHEMA block.
    /// @param spec Block specification.
    /// @param body Schema body.
    /// @param name Schema name.
    /// @return Encoded SCHEMA block bytes.
    function schema(uint spec, string memory body, bytes32 name) internal pure returns (bytes memory) {
        return create(Keys.Schema, bytes.concat(bytes32(spec), text(body), name));
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
    /// @param cmd Command identifier.
    /// @param resources Packed resources assigned to the step.
    /// @param input Raw nested input payload.
    /// @return Encoded STEP block bytes.
    function step(uint cmd, uint resources, bytes memory input) internal pure returns (bytes memory) {
        return create(Keys.Step, bytes.concat(bytes32(cmd), bytes32(resources), data(input)));
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
    /// @param input Embedded input block stream.
    /// @return Encoded CONTEXT block bytes.
    function context(bytes32 account, bytes memory state, bytes memory input) internal pure returns (bytes memory) {
        return create(Keys.Context, bytes.concat(account, data(state), data(input)));
    }

    /// @notice Encode a RELAY block.
    /// @param portal Destination portal identifier, often the destination host ID.
    /// @param resources Chain-specific resources for the destination context.
    /// @param input Nested input block stream.
    /// @return Encoded RELAY block bytes.
    function relay(uint portal, uint resources, bytes memory input) internal pure returns (bytes memory) {
        return create(Keys.Relay, bytes.concat(bytes32(portal), bytes32(resources), data(input)));
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
