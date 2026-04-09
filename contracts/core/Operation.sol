// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AccessControl } from "./Access.sol";
import { Assets } from "../utils/Assets.sol";
import { Ids } from "../utils/Ids.sol";
import { Cur, Cursors } from "../Cursors.sol";

error FailedCall(address addr, uint node, bytes4 selector, bytes err);

abstract contract OperationBase is AccessControl {
    bytes32 public immutable valueAsset = Assets.toValue();

    function cursor(bytes calldata source, uint g) internal pure returns (Cur memory cur) {
        (cur,,) = Cursors.init(source, g);
    }

    function cursors(
        bytes calldata state,
        bytes calldata request,
        uint sd,
        uint rd
    ) internal pure returns (Cur memory stateCur, Cur memory requestCur) {
        stateCur = cursor(state, sd);
        requestCur = cursor(request, rd);
    }

    function callTo(uint node, uint value, bytes memory data) internal returns (bytes memory out) {
        bool success;
        address addr = Ids.nodeAddr(ensureTrusted(node));
        (success, out) = payable(addr).call{value: value}(data);
        if (!success) {
            revert FailedCall(addr, node, bytes4(data), out);
        }
    }
}




