import { ethers } from "ethers";

// Block key derivation: bytes4(keccak256(schema))
export function blockKey(schema: string): string {
  return ethers.dataSlice(ethers.id(schema), 0, 4);
}

// Known block keys
export const Keys = {
  Amount: blockKey("amount(bytes32 asset, bytes32 meta, uint amount)"),
  Balance: blockKey("balance(bytes32 asset, bytes32 meta, uint amount)"),
  Allocation: blockKey("allocation(uint host, bytes32 asset, bytes32 meta, uint amount)"),
  Allowance: blockKey("allowance(uint host, bytes32 asset, bytes32 meta, uint amount)"),
  Custody: blockKey("custody(uint host, bytes32 asset, bytes32 meta, uint amount)"),
  Bounds: blockKey("bounds(int min, int max)"),
  Fee: blockKey("fee(uint amount)"),
  Account: blockKey("account(bytes32 account)"),
  Payout: blockKey("payout(bytes32 account, bytes32 asset, bytes32 meta, uint amount)"),
  Node: blockKey("node(uint id)"),
  Relocation: blockKey("relocation(uint host, uint amount)"),
  Asset: blockKey("asset(bytes32 asset, bytes32 meta)"),
  Quantity: blockKey("quantity(uint amount)"),
  Step: blockKey("step(uint target, uint value, bytes request)"),
  Call: blockKey("call(uint target, uint value, bytes data)"),
  Transaction: blockKey("transaction(bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)"),
  Minimum: blockKey("minimum(bytes32 asset, bytes32 meta, uint amount)"),
  Maximum: blockKey("maximum(bytes32 asset, bytes32 meta, uint amount)"),
  Break: blockKey("break()"),
  Auth: blockKey("auth(uint cid, uint deadline, bytes proof)"),
  Bounty: blockKey("bounty(uint amount, bytes32 relayer)"),
  Bundle: blockKey("bundle(bytes data)"),
  List: blockKey("list(bytes data)"),
  Frame: blockKey("frame(bytes data)"),
  Route: blockKey("route(bytes data)"),
  Item: blockKey("item(bytes data)"),
  Evm: blockKey("evm(bytes data)"),
  Query: blockKey("query(bytes data)"),
  Response: blockKey("response(bytes data)"),
  Status: blockKey("status(bool ok)"),
  AssetAmount: blockKey("assetAmount(bytes32 asset, bytes32 meta, uint amount)"),
  AccountAsset: blockKey("accountAsset(bytes32 account, bytes32 asset, bytes32 meta)"),
  AccountAmount: blockKey("accountAmount(bytes32 account, bytes32 asset, bytes32 meta, uint amount)"),
  HostAmount: blockKey("hostAmount(uint host, bytes32 asset, bytes32 meta, uint amount)"),
  HostAccountAsset: blockKey("hostAccountAsset(uint host, bytes32 account, bytes32 asset, bytes32 meta)"),
  HostAccountAmount: blockKey("hostAccountAmount(uint host, bytes32 account, bytes32 asset, bytes32 meta, uint amount)"),
} as const;

// Pad a bigint or hex string to 32 bytes
export function pad32(value: bigint | string): string {
  if (typeof value === "bigint") {
    return ethers.zeroPadValue(ethers.toBeHex(value), 32);
  }
  return ethers.zeroPadValue(value, 32);
}

export function padInt32(value: bigint): string {
  return ethers.zeroPadValue(ethers.toBeHex(BigInt.asUintN(256, value)), 32);
}

const USER_PREFIX = 0x20010102n;

export function encodeUserAccount(addr: string): string {
  const account = (USER_PREFIX << 224n) | (BigInt(ethers.zeroPadValue(addr, 20)) << 32n);
  return ethers.zeroPadValue(ethers.toBeHex(account), 32);
}

// Encode a 4-byte big-endian uint32
function encodeUint32(value: number): string {
  return ethers.toBeHex(value, 4);
}

// Build a block header + payload
function block(key: string, payload: string): string {
  const payloadBytes = ethers.getBytes(payload);
  return ethers.concat([key, encodeUint32(payloadBytes.length), payload]);
}

export function encodeAmountBlock(asset: string, meta: string, amount: bigint): string {
  return block(Keys.Amount, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeAmountBlockWithNode(asset: string, meta: string, amount: bigint, nodeId: bigint): string {
  return encodeBundleBlock(
    encodeAmountBlock(asset, meta, amount),
    encodeNodeBlock(nodeId),
  );
}

export function encodeAmountBlockWithAccount(asset: string, meta: string, amount: bigint, account: string): string {
  return encodeBundleBlock(
    encodeAmountBlock(asset, meta, amount),
    encodeAccountBlock(account),
  );
}

export function encodeBalanceBlock(asset: string, meta: string, amount: bigint): string {
  return block(Keys.Balance, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeHostAccountAssetBlock(host: bigint, account: string, asset: string, meta: string): string {
  return block(Keys.HostAccountAsset, ethers.concat([pad32(host), pad32(account), pad32(asset), pad32(meta)]));
}

export function encodeAccountAssetBlock(account: string, asset: string, meta: string): string {
  return block(Keys.AccountAsset, ethers.concat([pad32(account), pad32(asset), pad32(meta)]));
}

export function encodePayoutBlock(account: string, asset: string, meta: string, amount: bigint): string {
  return block(Keys.Payout, ethers.concat([pad32(account), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeAccountAmountBlock(account: string, asset: string, meta: string, amount: bigint): string {
  return block(Keys.AccountAmount, ethers.concat([pad32(account), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeAllocationBlock(host: bigint, asset: string, meta: string, amount: bigint): string {
  return block(Keys.Allocation, ethers.concat([pad32(host), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeAllowanceBlock(host: bigint, asset: string, meta: string, amount: bigint): string {
  return block(Keys.Allowance, ethers.concat([pad32(host), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeCustodyBlock(host: bigint, asset: string, meta: string, amount: bigint): string {
  return block(Keys.Custody, ethers.concat([pad32(host), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeAccountBlock(account: string): string {
  return block(Keys.Account, pad32(account));
}

export function encodeNodeBlock(id: bigint): string {
  return block(Keys.Node, pad32(id));
}

export function encodeRelocationBlock(host: bigint, amount: bigint): string {
  return block(Keys.Relocation, ethers.concat([pad32(host), pad32(amount)]));
}

export function encodeAssetBlock(asset: string, meta: string): string {
  return block(Keys.Asset, ethers.concat([pad32(asset), pad32(meta)]));
}

export function encodeQuantityBlock(amount: bigint): string {
  return block(Keys.Quantity, pad32(amount));
}

export function encodeBoundsBlock(min: bigint, max: bigint): string {
  return block(Keys.Bounds, ethers.concat([padInt32(min), padInt32(max)]));
}

export function encodeFeeBlock(amount: bigint): string {
  return block(Keys.Fee, pad32(amount));
}

export function encodeTxBlock(from: string, to: string, asset: string, meta: string, amount: bigint): string {
  return block(Keys.Transaction, ethers.concat([pad32(from), pad32(to), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeStepBlock(target: bigint, value: bigint, request: string): string {
  return block(Keys.Step, ethers.concat([pad32(target), pad32(value), request]));
}

export function encodeCallBlock(target: bigint, value: bigint, data: string): string {
  return block(Keys.Call, ethers.concat([pad32(target), pad32(value), data]));
}

export function encodeRouteBlock(data: string): string {
  return block(Keys.Route, data);
}

export function encodeEvmBlock(data: string): string {
  return block(Keys.Evm, data);
}

export function encodeQueryBlock(data: string): string {
  return block(Keys.Query, data);
}

export function encodeResponseBlock(data: string): string {
  return block(Keys.Response, data);
}

export function encodeStatusBlock(ok: boolean): string {
  return block(Keys.Status, pad32(ok ? 1n : 0n));
}

export function encodeBreakBlock(): string {
  return block(Keys.Break, "0x");
}

export function encodeBundleBlock(...members: string[]): string {
  return block(Keys.Bundle, concat(...members));
}

export function encodeListBlock(...members: string[]): string {
  return block(Keys.List, concat(...members));
}

export function encodeFrameBlock(...payloads: string[]): string {
  return block(Keys.Frame, concat(...payloads));
}

export function encodeRouteBlockWithAmount(data: string, asset: string, meta: string, amount: bigint): string {
  return encodeBundleBlock(encodeRouteBlock(data), encodeAmountBlock(asset, meta, amount));
}

export function encodeRouteBlockWithMinimum(data: string, asset: string, meta: string, amount: bigint): string {
  return encodeBundleBlock(encodeRouteBlock(data), encodeMinimumBlock(asset, meta, amount));
}

export function encodeBundleBlockWithMinimum(data: string, asset: string, meta: string, amount: bigint): string {
  return encodeBundleBlock(encodeRouteBlock(data), encodeMinimumBlock(asset, meta, amount));
}

export function encodeAuthBlock(cid: bigint, deadline: bigint, proof: string): string {
  return block(Keys.Auth, ethers.concat([pad32(cid), pad32(deadline), proof]));
}

export function encodeMinimumBlock(asset: string, meta: string, amount: bigint): string {
  return block(Keys.Minimum, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeMaximumBlock(asset: string, meta: string, amount: bigint): string {
  return block(Keys.Maximum, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeBountyBlock(amount: bigint, relayer: string): string {
  return block(Keys.Bounty, ethers.concat([pad32(amount), pad32(relayer)]));
}

export function concat(...parts: string[]): string {
  return ethers.concat(parts);
}

// Command args suffix appended when computing command selectors
const COMMAND_ARGS = "((bytes32,bytes,bytes))";

export function commandSelector(name: string): string {
  return ethers.dataSlice(ethers.id(name + COMMAND_ARGS), 0, 4);
}


