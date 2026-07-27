// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Keys} from "./Keys.sol";

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
    /// @dev AUTH block: 8 header + 32 cid + 32 deadline + nested BYTES block with 85-byte proof = 165 bytes
    uint constant Auth = B64 + Header + Proof;
    /// @dev STATUS block: 8 header + 32 status code = 40 bytes
    uint constant Status = B32;
    /// @dev AMOUNT block: 8 header + 32 asset + 32 amount = 72 bytes
    uint constant Amount = B64;
    /// @dev BALANCE block: 8 header + 32 asset + 32 amount = 72 bytes
    uint constant Balance = B64;
    /// @dev BALANCE_LIMIT block: 8 header + 32 asset + 32 min + 32 max = 104 bytes
    uint constant BalanceLimit = B96;
    /// @dev FEE block: 8 header + 32 amount = 40 bytes
    uint constant Fee = B32;
    /// @dev BOUNTY block: 8 header + 32 amount + 32 relayer = 72 bytes
    uint constant Bounty = B64;
    /// @dev ALLOCATION/CUSTODY block: 8 header + 32 host + 32 asset + 32 amount = 104 bytes
    uint constant HostAmount = B96;
    /// @dev CUSTODY_LIMIT block: 8 header + 32 host + 32 asset + 32 min + 32 max = 136 bytes
    uint constant CustodyLimit = B128;
    /// @dev TRANSACTION block: 8 header + 32 from + 32 to + 32 asset + 32 amount = 136 bytes
    uint constant Transaction = B128;
}

/// @title Specs
/// @notice Word-aligned block specifications encoded as
/// `[key:4][min:4][max:4][hint:4][group:1][container:4][reserved:11]`.
/// The upper eight bytes of a fixed-layout spec are its encoded block header,
/// allowing the entire spec word to be written directly as that header.
/// A maximum of zero means unbounded and requires a growable writer.
library Specs {
    /// @dev A payload is incompatible with its block specification.
    error InvalidSpec();

    uint private constant MinShift = 192;
    uint private constant MaxShift = 160;
    uint private constant HintShift = 128;
    uint private constant GroupShift = 120;
    uint private constant ContainerShift = 88;
    uint private constant SizeFields = (uint(1) << MinShift) | (uint(1) << MaxShift) | (uint(1) << HintShift);
    uint private constant MinMask = uint(type(uint32).max) << MinShift;
    uint private constant MaxMask = uint(type(uint32).max) << MaxShift;
    uint private constant ContainerMask = uint(type(uint32).max) << ContainerShift;
    uint private constant GroupMask = uint(type(uint8).max) << GroupShift;

    // Reusable field shapes keep public specs readable while remaining valid
    // compile-time constant expressions.
    uint private constant Exact32 = 32 * SizeFields;
    uint private constant Exact64 = 64 * SizeFields;
    uint private constant Exact96 = 96 * SizeFields;
    uint private constant Exact128 = 128 * SizeFields;
    uint private constant ExactAuth = (Sizes.Auth - Sizes.Header) * SizeFields;
    uint private constant UnboundedHint128 = uint(128) << HintShift;
    uint private constant UnboundedMin72Hint256 = (uint(72) << MinShift) | (uint(256) << HintShift);
    uint private constant UnboundedMin48Hint512 = (uint(48) << MinShift) | (uint(512) << HintShift);
    uint private constant UnboundedMin104Hint256 = (uint(104) << MinShift) | (uint(256) << HintShift);

    uint constant Empty = uint(bytes32(Keys.Empty));
    uint constant Any = uint(bytes32(Keys.Any)) | UnboundedHint128;
    uint constant Amount = uint(bytes32(Keys.Amount)) | Exact64;
    uint constant Balance = uint(bytes32(Keys.Balance)) | Exact64;
    uint constant BalanceLimit = uint(bytes32(Keys.BalanceLimit)) | Exact96;
    uint constant Allocation = uint(bytes32(Keys.Allocation)) | Exact96;
    uint constant Allowance = uint(bytes32(Keys.Allowance)) | Exact96;
    uint constant Custody = uint(bytes32(Keys.Custody)) | Exact96;
    uint constant CustodyLimit = uint(bytes32(Keys.CustodyLimit)) | Exact128;
    uint constant Fee = uint(bytes32(Keys.Fee)) | Exact32;
    uint constant List = uint(bytes32(Keys.List)) | UnboundedHint128;
    uint constant Evm = uint(bytes32(Keys.Evm)) | UnboundedHint128;
    uint constant Bytes = uint(bytes32(Keys.Bytes)) | UnboundedHint128;
    uint constant String = uint(bytes32(Keys.String)) | UnboundedHint128;
    uint constant Account = uint(bytes32(Keys.Account)) | Exact32;
    uint constant Transaction = uint(bytes32(Keys.Transaction)) | Exact128;
    uint constant Step = uint(bytes32(Keys.Step)) | UnboundedMin72Hint256;
    uint constant Relay = uint(bytes32(Keys.Relay)) | UnboundedMin72Hint256;
    uint constant Context = uint(bytes32(Keys.Context)) | UnboundedMin48Hint512;
    uint constant Recover = uint(bytes32(Keys.Recover)) | UnboundedMin104Hint256;
    uint constant Dispatch = uint(bytes32(Keys.Dispatch)) | UnboundedMin72Hint256;
    uint constant Call = uint(bytes32(Keys.Call)) | UnboundedMin72Hint256;
    uint constant Auth = uint(bytes32(Keys.Auth)) | ExactAuth;
    uint constant Asset = uint(bytes32(Keys.Asset)) | Exact32;
    uint constant Node = uint(bytes32(Keys.Node)) | Exact32;
    uint constant Bounty = uint(bytes32(Keys.Bounty)) | Exact64;
    uint constant Label = uint(bytes32(Keys.Label)) | UnboundedMin72Hint256;
    uint constant Schema = uint(bytes32(Keys.Schema)) | UnboundedMin72Hint256;

    uint constant Status = uint(bytes32(Keys.Status)) | Exact32;
    uint constant AssetAmount = uint(bytes32(Keys.AssetAmount)) | Exact64;
    uint constant AccountAsset = uint(bytes32(Keys.AccountAsset)) | Exact64;
    uint constant AccountAmount = uint(bytes32(Keys.AccountAmount)) | Exact96;
    uint constant HostAmount = uint(bytes32(Keys.HostAmount)) | Exact96;
    uint constant HostAccountAsset = uint(bytes32(Keys.HostAccountAsset)) | Exact96;
    uint constant HostAccountAmount = uint(bytes32(Keys.HostAccountAmount)) | Exact128;

    /// @notice Construct a block specification from its encoded fields.
    /// @param blockKey Encoded block key.
    /// @param minimum Minimum accepted payload length.
    /// @param maximum Maximum accepted payload length; zero means unbounded.
    /// @param payloadHint Initial per-block payload capacity.
    function create(
        bytes4 blockKey,
        uint32 minimum,
        uint32 maximum,
        uint32 payloadHint
    ) internal pure returns (uint) {
        return (uint(uint32(blockKey)) << 224) | (uint(minimum) << MinShift) | (uint(maximum) << MaxShift)
            | (uint(payloadHint) << HintShift);
    }

    /// @notice Return the block key encoded in `spec`.
    function key(uint spec) internal pure returns (bytes4) {
        return bytes4(uint32(spec >> 224));
    }

    /// @notice Return the minimum accepted payload length.
    function min(uint spec) internal pure returns (uint32) {
        return uint32(spec >> 192);
    }

    /// @notice Return the maximum accepted payload length, or zero when unbounded.
    function max(uint spec) internal pure returns (uint32) {
        return uint32(spec >> MaxShift);
    }

    /// @notice Return the initial per-block payload capacity.
    function hint(uint spec) internal pure returns (uint32) {
        return uint32(spec >> HintShift);
    }

    /// @notice Return an exact payload size constrained to an accepted range.
    function exact(uint spec, uint minimum, uint maximum) internal pure returns (uint size) {
        size = min(spec);
        if (size != max(spec) || size < minimum || size > maximum) revert InvalidSpec();
    }

    /// @notice Validate a payload size against a specification's bounds.
    function validate(uint spec, uint size) internal pure {
        uint minimum = min(spec);
        uint maximum = max(spec);
        if (size < minimum || (maximum != 0 && size > maximum)) revert InvalidSpec();
    }

    /// @notice Return the eight-byte header portion of `spec`.
    /// @dev This is a valid encoded header when the spec describes a fixed block.
    function header(uint spec) internal pure returns (bytes8) {
        return bytes8(uint64(spec >> 192));
    }

    /// @notice Return the optional container block key encoded in `spec`.
    function container(uint spec) internal pure returns (bytes4) {
        return bytes4(uint32(spec >> ContainerShift));
    }

    /// @notice Return the effective descriptor group encoded in `spec`.
    /// @dev A non-empty spec with an encoded group of zero defaults to one.
    function group(uint spec) internal pure returns (uint8 size) {
        size = uint8(spec >> GroupShift);
        if (size == 0 && key(spec) != bytes4(0)) size = 1;
    }

    /// @notice Return `spec` annotated with a descriptor container spec.
    /// @dev Only the container spec's block key is embedded.
    function withContainer(uint spec, uint containerSpec) internal pure returns (uint) {
        return (spec & ~ContainerMask) | (uint(uint32(key(containerSpec))) << ContainerShift);
    }

    /// @notice Return `spec` annotated with an explicit descriptor group.
    function withGroup(uint spec, uint8 groupSize) internal pure returns (uint) {
        return (spec & ~GroupMask) | (uint(groupSize) << GroupShift);
    }

    /// @notice Return `spec` annotated with payload validation bounds.
    /// @dev A maximum of zero means unbounded.
    function withRange(uint spec, uint32 minimum, uint32 maximum) internal pure returns (uint) {
        return (spec & ~(MinMask | MaxMask)) | (uint(minimum) << MinShift) | (uint(maximum) << MaxShift);
    }

    /// @notice Return `spec` annotated with a descriptor container spec and group.
    function derive(uint spec, uint containerSpec, uint8 groupSize) internal pure returns (uint) {
        return withGroup(withContainer(spec, containerSpec), groupSize);
    }

    /// @notice Return whether `spec` requires a growable buffer.
    /// @dev A maximum of zero denotes an unbounded payload length.
    function growable(uint spec) internal pure returns (bool) {
        return max(spec) == 0;
    }
}
