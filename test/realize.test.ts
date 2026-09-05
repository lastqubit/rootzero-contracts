import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import {
  concat, encodeAssetBlock, encodeAmountBlock, encodeAssetLiabilityBlock, encodeBalanceBlock,
  encodeDebtBlock, encodePositionBlock, encodeContextBlock,
} from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Realization failure atomicity", () => {
  const asset = ethers.zeroPadValue("0x11", 32);
  const liability = ethers.zeroPadValue("0x22", 32);
  const to = ethers.zeroPadValue("0x33", 32);
  const balance = encodeBalanceBlock(asset, 10n);
  const debt = encodeDebtBlock(liability, 7n);
  const position = encodePositionBlock(asset, 10n, liability, 7n);
  const assetInput = encodeAmountBlock(to, 0n);
  const debtInput = encodeAmountBlock(to, ethers.MaxUint256);
  const positionInput = concat(assetInput, debtInput);
  const context = (state: string, input: string) => encodeContextBlock(ethers.ZeroHash, state, input);
  let helper: Awaited<ReturnType<typeof deploy>>;

  beforeEach(async () => {
    helper = await deploy("TestRealize");
    // Establish nonzero committed state so rollback must preserve earlier work.
    await (await helper.realizePosition(context(position, positionInput))).wait();
  });

  async function committedState() {
    return Promise.all([
      helper.assetCalls(), helper.debtCalls(), helper.realizedAssets(), helper.realizedDebts(),
    ]);
  }

  async function rejectsWithoutChanges(method: string, state: string, input: string, error: string) {
    const before = await committedState();
    await expect(helper[method](context(state, input), { gasLimit: 3_000_000 }))
      .to.be.revertedWithCustomError(helper, error);
    expect(await committedState()).to.deep.equal(before);
  }

  for (const [method, state, input, wrongStates] of [
    ["realize", balance, assetInput, [debt, position]],
    ["realizeDebt", debt, debtInput, [balance, position]],
    ["realizePosition", position, positionInput, [balance, debt]],
  ] as const) {
    describe(method, () => {
      if (method === "realizePosition") {
        it("rejects the old ASSET_LIABILITY input shape", async () => {
          await rejectsWithoutChanges(method, state, encodeAssetLiabilityBlock(to, liability), "InvalidBlock");
        });

        it("delegates both limit checks entirely to the hooks", async () => {
          await (await helper.setEnforceLimits(false)).wait();
          const inputs = concat(encodeAmountBlock(to, 11n), encodeAmountBlock(liability, 6n));
          expect(await helper.realizePosition.staticCall(context(state, inputs)))
            .to.deep.equal([encodePositionBlock(to, 10n, liability, 7n), 0n]);
        });

        for (const pair of [1, 2]) {
          for (const side of ["asset", "debt"]) {
            it(`rolls back all hooks when position ${pair} violates its ${side} limit`, async () => {
              const invalid = side === "asset"
                ? concat(encodeAmountBlock(to, 11n), debtInput)
                : concat(assetInput, encodeAmountBlock(to, 6n));
              await rejectsWithoutChanges(method, concat(state, state),
                pair === 1 ? concat(invalid, input) : concat(input, invalid),
                side === "asset" ? "AmountBelowLimit" : "DebtAboveLimit");
            });
          }

          for (const [label, second, error] of [
            ["missing", "0x", "OutOfBounds"],
            ["truncated", ethers.dataSlice(debtInput, 0, 71), "OutOfBounds"],
            ["wrong type", debt, "InvalidBlock"],
            ["wrong payload length", concat(ethers.dataSlice(debtInput, 0, 4), "0x00000000", ethers.dataSlice(debtInput, 8)), "InvalidBlock"],
          ] as const) {
            it(`rolls back the asset hook when position ${pair}'s second AMOUNT is ${label}`, async () => {
              await rejectsWithoutChanges(method,
                pair === 1 ? state : concat(state, state),
                concat(pair === 1 ? "0x" : input, assetInput, second), error);
            });
          }
        }

        it("rejects an extra unpaired AMOUNT after a complete position", async () => {
          await rejectsWithoutChanges(method, state, concat(input, assetInput), "OutOfBounds");
        });
      } else {
        it("delegates limit enforcement entirely to the hook", async () => {
          await (await helper.setEnforceLimits(false)).wait();
          const limit = method === "realize" ? 11n : 6n;
          const output = method === "realize" ? encodeBalanceBlock(to, 10n) : encodeDebtBlock(to, 7n);
          expect(await helper[method].staticCall(context(state, encodeAmountBlock(to, limit))))
            .to.deep.equal([output, 0n]);
        });

        it("rejects the old ASSET input shape", async () => {
          await rejectsWithoutChanges(method, state, encodeAssetBlock(to), "OutOfBounds");
        });

        for (const pair of [1, 2]) {
          it(`rolls back hook mutations when pair ${pair} violates its output limit`, async () => {
            const invalid = encodeAmountBlock(to, method === "realize" ? 11n : 6n);
            const inputs = pair === 1 ? concat(invalid, input) : concat(input, invalid);
            // The fixture hooks enforce limits after mutation to exercise rollback.
            await rejectsWithoutChanges(method, concat(state, state), inputs,
              method === "realize" ? "AmountBelowLimit" : "DebtAboveLimit");
          });
        }
      }

      it("rolls back a completed pair when nonempty state outnumbers input", async () => {
        await rejectsWithoutChanges(method, concat(state, state), input, "OutOfBounds");
      });

      it("rolls back a completed pair when nonempty input outnumbers state", async () => {
        await rejectsWithoutChanges(method, state, concat(input, input), "OutOfBounds");
      });

      for (const wrongState of wrongStates) {
        it(`rejects trailing state type ${wrongState.slice(0, 10)} and rolls back earlier pairs`, async () => {
          await rejectsWithoutChanges(method, concat(state, wrongState), concat(input, input),
            wrongState.length < state.length ? "OutOfBounds" : "InvalidBlock");
        });
      }

      for (const lane of ["state", "input"] as const) {
        for (const defect of ["partial header", "truncated payload", "wrong key", "wrong payload length"] as const) {
          it(`rolls back earlier pairs for a trailing ${lane} block with ${defect}`, async () => {
            const block = lane === "state" ? state : input;
            const malformed = defect === "partial header" ? ethers.dataSlice(block, 0, 7)
              : defect === "truncated payload" ? ethers.dataSlice(block, 0, ethers.dataLength(block) - 1)
              : defect === "wrong key" ? "0xffffffff" + block.slice(10)
              : concat(ethers.dataSlice(block, 0, 4), "0x00000000", ethers.dataSlice(block, 8));
            await rejectsWithoutChanges(method,
              concat(state, lane === "state" ? malformed : state),
              concat(input, lane === "input" ? malformed : input),
              defect === "partial header" || defect === "truncated payload" ? "OutOfBounds" : "InvalidBlock");
          });
        }
      }

      for (const hook of method === "realizePosition" ? ["asset", "debt"] : [method === "realize" ? "asset" : "debt"]) {
        for (const pair of [1, 2]) {
          it(`rolls back the whole batch when the ${hook} hook fails on pair ${pair}`, async () => {
            const failureAt = BigInt(pair + 1); // One pair was committed in beforeEach.
            await (await helper.failAt(hook === "asset" ? failureAt : 0n, hook === "debt" ? failureAt : 0n)).wait();
            let data: string | undefined;
            try {
              await helper[method].staticCall(context(concat(state, state), concat(input, input)));
            } catch (error: any) {
              data = error.data ?? error.info?.error?.data;
            }
            expect(data, "hook must revert").to.be.a("string");
            const failure = helper.interface.parseError(data!);
            expect(failure?.name).to.equal(hook === "asset" ? "AssetFailure" : "DebtFailure");
            // For POSITION, a debt failure must observe the preceding asset hook's
            // mutation; committed counters and totals must nevertheless roll back.
            const assets = method === "realizeDebt" ? 1n : failureAt;
            const debts = method === "realize" ? 1n
              : method === "realizePosition" && hook === "asset" ? failureAt - 1n : failureAt;
            expect([...failure!.args]).to.deep.equal([assets, debts]);
            await rejectsWithoutChanges(method, concat(state, state), concat(input, input),
              hook === "asset" ? "AssetFailure" : "DebtFailure");
          });
        }
      }
    });
  }
});
