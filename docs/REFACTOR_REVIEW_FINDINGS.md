# Refactor Review Findings

Review date: 2026-04-25
Status: fixed in the working tree

Scope reviewed:
- Current working tree, including the uncommitted refactor changes.
- Block cursor/writer primitives, command and peer entrypoints, query entrypoints, ID/asset/account helpers, events, and the updated frame example.
- Test suite result after fixes: `npm.cmd test` passes with 318 tests. Hardhat warns that Node.js 25.3.0 is unsupported.

## Findings

### P1 - Fixed: `requireAuth` advanced by payload length, not full block length

Location: `contracts/blocks/Cursors.sol:1312`

`requireAuth` validates the current AUTH block with `expectAuth`, but then advances the cursor by only `64 + proof.length`.

For the standard proof layout, the AUTH payload is:

- 32 bytes `cid`
- 32 bytes `deadline`
- 85 bytes `proof`

That is 149 payload bytes. The encoded block also has the shared 8-byte header, so the cursor must advance by 157 bytes. The current code advances by 149 and leaves `cur.i` pointing 8 bytes before the actual end of the AUTH block.

Impact:
- A caller that parses another block after `requireAuth` starts reading inside the AUTH proof tail.
- A caller that expects the cursor to be at the end of an AUTH-only source will fail completion checks or carry a subtly incorrect cursor position.
- The current test locks in the wrong behavior: `test/blocks.test.ts:337` says "advances by the auth block size", but `test/blocks.test.ts:343` expects `149n`, which is the payload size, not the block size.

Applied fix:
- Have `expectAuth` return `next`, or recompute the full block size in `requireAuth`, and set `cur.i` to the actual next block offset.
- Update the test expectation from `149n` to `157n`.

Suggested shape:

```solidity
function requireAuth(Cur memory cur, uint cid) internal pure returns (uint deadline, bytes calldata proof) {
    (deadline, proof) = expectAuth(cur, cur.i, cid);
    cur.i += Sizes.Header + 64 + proof.length;
}
```

Concrete patch:

```diff
diff --git a/contracts/blocks/Cursors.sol b/contracts/blocks/Cursors.sol
@@
     function requireAuth(Cur memory cur, uint cid) internal pure returns (uint deadline, bytes calldata proof) {
         (deadline, proof) = expectAuth(cur, cur.i, cid);
-        cur.i += 64 + proof.length;
+        cur.i += Sizes.Header + 64 + proof.length;
     }
```

Test update:

```diff
diff --git a/test/blocks.test.ts b/test/blocks.test.ts
@@
       const [deadline, outProof, i] = await helper.testRequireAuth(source, 77n);
       expect(deadline).to.equal(123456n);
       expect(outProof).to.equal(proof);
-      expect(i).to.equal(149n);
+      expect(i).to.equal(157n);
     });
```

### P2 - Fixed: `Writer.end` recorded logical capacity but was not enforced

Location: `contracts/blocks/Writers.sol:47`, `contracts/blocks/Writers.sol:291`, `contracts/blocks/Writers.sol:386`, `contracts/blocks/Writers.sol:914`

`alloc(len)` records the exact requested capacity in `writer.end`, but write paths check only the padded backing buffer length (`writer.dst.length`). `finish` also checks only `writer.dst.length`.

Because allocation intentionally pads the backing buffer for full-word stores, a writer can emit more bytes than the logical capacity requested by `alloc*`.

Example:
- `Writers.alloc32s(1)` asks for one 40-byte block.
- `alloc(40)` creates a 96-byte backing buffer.
- Two `appendBlock32(...)` calls write 80 logical bytes and still pass the current `dst.length` checks.
- `finish` returns an 80-byte output even though the writer was allocated for one response block.

Impact:
- Count-based response allocation no longer enforces the promised output cardinality.
- Hook-based writers such as `AssetPosition.appendAssetPosition` can accidentally append too many or oversized response blocks without failing until they exceed padded physical capacity.
- Tests that rely on allocation as a guard may miss overproduction by up to the padding slack.

Applied fix:
- Enforce `next <= writer.end` at the append layer, while still allowing the backing buffer to be physically padded for full-word `mstore`.
- Also make `finish` reject `writer.i > writer.end` so manual mutation cannot bypass append checks.
- Add tests that an `alloc32s(1)` writer rejects a second full block and that an `allocBytes(1, n)` writer rejects an oversized dynamic response.

Concrete contract patch:

```diff
diff --git a/contracts/blocks/Writers.sol b/contracts/blocks/Writers.sol
@@
     function writeHeader(bytes memory dst, uint i, bytes4 key, uint32 len) private pure returns (uint p) {
         uint header = (uint(uint32(key)) << 224) | (uint(len) << 192);
         assembly ("memory-safe") {
             p := add(add(dst, 0x20), i)
             mstore(p, header)
         }
     }
+
+    /// @notice Commit a logical writer advance after a low-level write.
+    /// @dev Low-level write helpers validate the padded backing buffer. This
+    ///      enforces the caller-requested logical capacity recorded in `end`.
+    function commit(Writer memory writer, uint next) private pure {
+        if (next > writer.end) revert WriterOverflow();
+        writer.i = next;
+    }
@@
     function append(Writer memory writer, bytes memory data) internal pure {
-        writer.i = write(writer.dst, writer.i, data);
+        commit(writer, write(writer.dst, writer.i, data));
     }
@@
     function append32(Writer memory writer, bytes32 value, uint keep) internal pure {
-        writer.i = write32(writer.dst, writer.i, value, keep);
+        commit(writer, write32(writer.dst, writer.i, value, keep));
     }
@@
     function append64(Writer memory writer, bytes32 a, bytes32 b, uint keep) internal pure {
-        writer.i = write64(writer.dst, writer.i, a, b, keep);
+        commit(writer, write64(writer.dst, writer.i, a, b, keep));
     }
@@
     function append96(Writer memory writer, bytes32 a, bytes32 b, bytes32 c, uint keep) internal pure {
-        writer.i = write96(writer.dst, writer.i, a, b, c, keep);
+        commit(writer, write96(writer.dst, writer.i, a, b, c, keep));
     }
@@
     function appendBlock(Writer memory writer, bytes4 key, bytes memory data) internal pure {
-        writer.i = writeBlock(writer.dst, writer.i, key, data);
+        commit(writer, writeBlock(writer.dst, writer.i, key, data));
     }
@@
     function appendBlock32(Writer memory writer, bytes4 key, bytes32 a, uint keep) internal pure {
-        writer.i = writeBlock32(writer.dst, writer.i, key, a, keep);
+        commit(writer, writeBlock32(writer.dst, writer.i, key, a, keep));
     }
@@
     function appendBlock64(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, uint keep) internal pure {
-        writer.i = writeBlock64(writer.dst, writer.i, key, a, b, keep);
+        commit(writer, writeBlock64(writer.dst, writer.i, key, a, b, keep));
     }
@@
     function appendBlock96(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, bytes32 c, uint keep) internal pure {
-        writer.i = writeBlock96(writer.dst, writer.i, key, a, b, c, keep);
+        commit(writer, writeBlock96(writer.dst, writer.i, key, a, b, c, keep));
     }
@@
     ) internal pure {
-        writer.i = writeBlock128(writer.dst, writer.i, key, a, b, c, d, keep);
+        commit(writer, writeBlock128(writer.dst, writer.i, key, a, b, c, d, keep));
     }
@@
     ) internal pure {
-        writer.i = writeBlock160(writer.dst, writer.i, key, a, b, c, d, e, keep);
+        commit(writer, writeBlock160(writer.dst, writer.i, key, a, b, c, d, e, keep));
     }
@@
     function appendBlockHead32(Writer memory writer, bytes4 key, bytes32 a, bytes memory tail) internal pure {
-        writer.i = writeBlockHead32(writer.dst, writer.i, key, a, tail);
+        commit(writer, writeBlockHead32(writer.dst, writer.i, key, a, tail));
     }
@@
     ) internal pure {
-        writer.i = writeBlockHead64(writer.dst, writer.i, key, a, b, tail);
+        commit(writer, writeBlockHead64(writer.dst, writer.i, key, a, b, tail));
     }
@@
     function appendBlockBool(Writer memory writer, bytes4 key, bool value) internal pure {
-        writer.i = writeBlockBool(writer.dst, writer.i, key, value);
+        commit(writer, writeBlockBool(writer.dst, writer.i, key, value));
     }
@@
     function appendBalance(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
-        writer.i = writeBlock96(writer.dst, writer.i, Keys.Balance, asset, meta, bytes32(amount), 32);
+        commit(writer, writeBlock96(writer.dst, writer.i, Keys.Balance, asset, meta, bytes32(amount), 32));
     }
@@
     function appendBalance(Writer memory writer, AssetAmount memory value) internal pure {
-        writer.i = writeBlock96(writer.dst, writer.i, Keys.Balance, value.asset, value.meta, bytes32(value.amount), 32);
+        commit(writer, writeBlock96(writer.dst, writer.i, Keys.Balance, value.asset, value.meta, bytes32(value.amount), 32));
     }
```

Apply the same `commit(writer, writeBlock*(...))` pattern to the remaining typed append helpers in `Writers.sol`: `appendUserPosition`, `appendAmount`, `appendUserAmount`, `appendAsset`, `appendBounty`, `appendHostedBalance`, and `appendTransaction`.

Then harden `finish`:

```diff
diff --git a/contracts/blocks/Writers.sol b/contracts/blocks/Writers.sol
@@
     function finish(Writer memory writer) internal pure returns (bytes memory out) {
         if (writer.i == 0) revert EmptyRequest();
-        if (writer.i > writer.dst.length) revert IncompleteWriter();
+        if (writer.i > writer.end || writer.i > writer.dst.length) revert IncompleteWriter();
         out = writer.dst;
         // Overwrite the memory length word of `out` with the actual written length.
         assembly ("memory-safe") {
             mstore(out, mload(writer))
         }
```

Suggested test helper additions:

```diff
diff --git a/contracts/test/TestCursorHelper.sol b/contracts/test/TestCursorHelper.sol
@@
     function testWriterFinish(bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
         Writer memory w = Writers.alloc(Sizes.Balance * 2);
         w.appendBalance(asset, meta, amount);
         return w.finish();
     }
+
+    function testWriterRejectsSecond32Block(bytes32 value) external pure returns (bytes memory) {
+        Writer memory w = Writers.alloc32s(1);
+        w.appendBlock32(Keys.Response, value, 32);
+        w.appendBlock32(Keys.Response, value, 32);
+        return w.finish();
+    }
+
+    function testWriterRejectsOversizedDynamicBlock(bytes memory data) external pure returns (bytes memory) {
+        Writer memory w = Writers.allocBytes(1, 32);
+        w.appendBlock(Keys.Response, data);
+        return w.finish();
+    }
```

Suggested test cases:

```diff
diff --git a/test/blocks.test.ts b/test/blocks.test.ts
@@
     it("finish truncates to actual written length", async () => {
       const data: string = await helper.testWriterFinish(asset, meta, amount);
       expect(ethers.getBytes(data).length).to.equal(104);
     });
+
+    it("reverts when appending past logical writer capacity", async () => {
+      await expect(helper.testWriterRejectsSecond32Block(asset))
+        .to.be.revertedWithCustomError(helper, "WriterOverflow");
+    });
+
+    it("reverts when a dynamic block exceeds allocated payload size", async () => {
+      const oversized = ethers.concat([asset, meta]);
+      await expect(helper.testWriterRejectsOversizedDynamicBlock(oversized))
+        .to.be.revertedWithCustomError(helper, "WriterOverflow");
+    });
```

## Notes

- I did not find stale call sites for the renamed writer/cursor helper APIs (`appendBlock*`, `writeBlock*`, `createBlock*`); the search came back clean.
- The full test suite is green, and both issues now have regression coverage.
