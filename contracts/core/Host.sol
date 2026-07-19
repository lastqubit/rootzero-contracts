// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessControl} from "./Access.sol";
import {Appoint} from "../commands/admin/Appoint.sol";
import {Authorize} from "../commands/admin/Authorize.sol";
import {Dismiss} from "../commands/admin/Dismiss.sol";
import {Unauthorize} from "../commands/admin/Unauthorize.sol";
import {ExecutePayable} from "../commands/admin/Execute.sol";
import {Label} from "../commands/admin/Label.sol";
import {Revoke} from "../guards/Revoke.sol";
import {IntroductionEvent} from "../events/Introduction.sol";
import {Nodes} from "../utils/Nodes.sol";

/// @title IHostIntroduction
/// @notice Interface implemented by hosts that accept introductions from other hosts.
interface IHostIntroduction {
    /// @notice Record a host introduction claim.
    /// @param peer Host node ID being introduced.
    /// @param blocknum Block number at which the introduction was made.
    function introduce(uint peer, uint blocknum) external;
}

/// @title Host
/// @notice Abstract base contract for rootzero host implementations.
/// Inherits admin command support (authorize, unauthorize, label, executePayable),
/// guardian management, the default guardian revoke action, and
/// optionally introduces itself to a commander host at deployment.
/// Accepts native ETH payments via the `receive` function.
abstract contract Host is
    Authorize,
    Unauthorize,
    Revoke,
    Appoint,
    Dismiss,
    Label,
    ExecutePayable,
    IntroductionEvent,
    IHostIntroduction
{
    /// @param cmdr Commander address; passed to `AccessControl`.
    ///        If `cmdr` is a deployed contract, the host calls `introduce`
    ///        on it during construction.
    constructor(address cmdr) AccessControl(cmdr) {
        if (cmdr == address(0) || cmdr == address(this) || cmdr.code.length == 0) return;
        introduceTo(Nodes.toHost(cmdr));
    }

    /// @notice Introduce this host to the contract address embedded in a local EVM node ID.
    /// @dev Accepts host and endpoint IDs such as commands, ports, queries, and guards.
    /// Reverts when `node` is not local or embeds the zero address.
    /// @param node Local EVM node ID whose underlying contract receives the introduction.
    function introduceTo(uint node) internal {
        IHostIntroduction(Nodes.addr(node)).introduce(host, block.number);
    }

    /// @notice Record a host introduction claim.
    /// @dev Validates that `peer` matches `msg.sender`; it does not authorize or trust the introduced host.
    /// @param peer Host node ID being introduced.
    /// @param blocknum Block number at which the host was deployed.
    function introduce(uint peer, uint blocknum) external {
        emit Introduction(host, Nodes.matchHost(peer, msg.sender), blocknum);
    }

    /// @notice Accept native ETH transfers (e.g. from command value flows).
    receive() external payable {}
}
