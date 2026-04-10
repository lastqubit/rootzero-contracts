// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cursors, Cur, Writers, Writer } from "../Cursors.sol";
import { ALLOC_SCALE } from "../blocks/Writers.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract InputToBalance {
    function inputToBalance(
        bytes32 account,
        Cur memory input
    ) internal virtual returns (bytes32 asset, bytes32 meta, uint amount);

    function inputsToBalances(bytes calldata blocks, uint i, bytes32 account) internal returns (bytes memory) {
        Cur memory scan = Cursors.open(blocks[i:]);
        (, uint count) = scan.primeRun(1);
        Writer memory writer = Writers.allocScaledBalances(count, ALLOC_SCALE);

        while (scan.i < scan.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = inputToBalance(account, scan);
            if (amount > 0) writer.appendBalance(asset, meta, amount);
        }

        return writer.finish();
    }
}




