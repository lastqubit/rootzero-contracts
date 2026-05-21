// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessControl} from "./Access.sol";
import {Authorize} from "../commands/admin/Authorize.sol";
import {Unauthorize} from "../commands/admin/Unauthorize.sol";
import {ExecutePayable} from "../commands/admin/Execute.sol";
import {IntroductionEvent} from "../events/Introduction.sol";

/// @title IHostIntroduction
/// @notice Interface implemented by hosts that accept introductions from other hosts.
interface IHostIntroduction {
    /// @notice Record a host introduction claim.
    /// @param id Host node ID.
    /// @param blocknum Block number at which the introduction was made.
    /// @param version Protocol version the host is running.
    /// @param namespace Human-readable namespace or label for the host.
    function introduce(uint id, uint blocknum, uint16 version, string calldata namespace) external;
}

/// @title Host
/// @notice Abstract base contract for rootzero host implementations.
/// Inherits admin command support (authorize, unauthorize, executePayable) and
/// optionally introduces itself to a commander host at deployment.
/// Accepts native ETH payments via the `receive` function.
abstract contract Host is Authorize, Unauthorize, ExecutePayable, IntroductionEvent, IHostIntroduction {
    /// @param cmdr Commander address; passed to `AccessControl`.
    ///        If `cmdr` is a deployed contract, the host calls `introduce`
    ///        on it during construction.
    /// @param version Protocol version number to publish in the announcement.
    /// @param namespace Human-readable namespace string for the host.
    constructor(address cmdr, uint16 version, string memory namespace) AccessControl(cmdr) {
        if (cmdr == address(0) || cmdr == address(this) || cmdr.code.length == 0) return;
        IHostIntroduction(cmdr).introduce(host, block.number, version, namespace);
    }

    /// @notice Record a host introduction claim.
    /// @dev This event is informational only; it does not authorize or trust the introduced host.
    /// @param id Host node ID.
    /// @param blocknum Block number at which the host was deployed.
    /// @param version Protocol version the host implements.
    /// @param namespace Human-readable namespace string for the host.
    function introduce(uint id, uint blocknum, uint16 version, string calldata namespace) external {
        emit Introduction(id, blocknum, version, namespace);
    }

    /// @notice Accept native ETH transfers (e.g. from command value flows).
    receive() external payable {}
}
