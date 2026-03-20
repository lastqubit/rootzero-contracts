import { ethers } from "ethers";

// Block key derivation: bytes4(keccak256(schema))
export function blockKey(schema: string): string {
  return ethers.dataSlice(ethers.id(schema), 0, 4);
}

// Known block keys
export const AMOUNT_KEY   = blockKey("amount(bytes32 asset, bytes32 meta, uint amount)");
export const BALANCE_KEY  = blockKey("balance(bytes32 asset, bytes32 meta, uint amount)");
export const CUSTODY_KEY  = blockKey("custody(uint host, bytes32 asset, bytes32 meta, uint amount)");
export const RECIPIENT_KEY = blockKey("recipient(bytes32 account)");
export const NODE_KEY     = blockKey("node(uint id)");
export const FUNDING_KEY  = blockKey("funding(uint host, uint amount)");
export const ASSET_KEY    = blockKey("asset(bytes32 asset, bytes32 meta)");
export const ALLOCATION_KEY = blockKey("allocation(uint host, bytes32 asset, bytes32 meta, uint amount)");
export const STEP_KEY     = blockKey("step(uint target, uint value, bytes request)");
export const TX_KEY       = blockKey("tx(bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)");
export const MINIMUM_KEY  = blockKey("minimum(bytes32 asset, bytes32 meta, uint amount)");
export const MAXIMUM_KEY  = blockKey("maximum(bytes32 asset, bytes32 meta, uint amount)");
export const AUTH_KEY     = blockKey("auth(uint cid, uint deadline, bytes proof)");
export const BOUNTY_KEY   = blockKey("bounty(uint amount, bytes32 relayer)");
export const ROUTE_KEY    = blockKey("route(bytes data)");

// Pad a bigint or hex string to 32 bytes
export function pad32(value: bigint | string): string {
  if (typeof value === "bigint") {
    return ethers.zeroPadValue(ethers.toBeHex(value), 32);
  }
  return ethers.zeroPadValue(value, 32);
}

// Encode a 4-byte big-endian uint32
function encodeUint32(value: number): string {
  return ethers.toBeHex(value, 4);
}

// Build a block header + payload
function block(key: string, payload: string): string {
  const payloadBytes = ethers.getBytes(payload);
  const selfLen = payloadBytes.length;
  const totalLen = selfLen; // no children
  return ethers.concat([key, encodeUint32(selfLen), encodeUint32(totalLen), payload]);
}

// Build a block with children
function blockWithChildren(key: string, payload: string, children: string): string {
  const payloadBytes = ethers.getBytes(payload);
  const childrenBytes = ethers.getBytes(children);
  const selfLen = payloadBytes.length;
  const totalLen = selfLen + childrenBytes.length;
  return ethers.concat([key, encodeUint32(selfLen), encodeUint32(totalLen), payload, children]);
}

export function encodeAmountBlock(asset: string, meta: string, amount: bigint): string {
  return block(AMOUNT_KEY, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeAmountBlockWithNode(asset: string, meta: string, amount: bigint, nodeId: bigint): string {
  return blockWithChildren(AMOUNT_KEY, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]), encodeNodeBlock(nodeId));
}

export function encodeAmountBlockWithRecipient(asset: string, meta: string, amount: bigint, recipient: string): string {
  return blockWithChildren(AMOUNT_KEY, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]), encodeRecipientBlock(recipient));
}

export function encodeBalanceBlock(asset: string, meta: string, amount: bigint): string {
  return block(BALANCE_KEY, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeCustodyBlock(host: bigint, asset: string, meta: string, amount: bigint): string {
  return block(CUSTODY_KEY, ethers.concat([pad32(host), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeRecipientBlock(account: string): string {
  return block(RECIPIENT_KEY, pad32(account));
}

export function encodeNodeBlock(id: bigint): string {
  return block(NODE_KEY, pad32(id));
}

export function encodeFundingBlock(host: bigint, amount: bigint): string {
  return block(FUNDING_KEY, ethers.concat([pad32(host), pad32(amount)]));
}

export function encodeAssetBlock(asset: string, meta: string): string {
  return block(ASSET_KEY, ethers.concat([pad32(asset), pad32(meta)]));
}

export function encodeAllocationBlock(host: bigint, asset: string, meta: string, amount: bigint): string {
  return block(ALLOCATION_KEY, ethers.concat([pad32(host), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeTxBlock(from: string, to: string, asset: string, meta: string, amount: bigint): string {
  return block(TX_KEY, ethers.concat([pad32(from), pad32(to), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeStepBlock(target: bigint, value: bigint, request: string): string {
  return block(STEP_KEY, ethers.concat([pad32(target), pad32(value), request]));
}

export function encodeRouteBlock(data: string): string {
  return block(ROUTE_KEY, data);
}

export function encodeRouteBlockWithAmount(data: string, asset: string, meta: string, amount: bigint): string {
  return blockWithChildren(ROUTE_KEY, data, encodeAmountBlock(asset, meta, amount));
}

export function encodeRouteBlockWithMinimum(data: string, asset: string, meta: string, amount: bigint): string {
  return blockWithChildren(ROUTE_KEY, data, encodeMinimumBlock(asset, meta, amount));
}

export function encodeAuthBlock(cid: bigint, deadline: bigint, proof: string): string {
  return block(AUTH_KEY, ethers.concat([pad32(cid), pad32(deadline), proof]));
}

export function encodeMinimumBlock(asset: string, meta: string, amount: bigint): string {
  return block(MINIMUM_KEY, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeMaximumBlock(asset: string, meta: string, amount: bigint): string {
  return block(MAXIMUM_KEY, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
}

export function concat(...parts: string[]): string {
  return ethers.concat(parts);
}

// Command args suffix appended when computing command selectors
const COMMAND_ARGS = "((uint256,bytes32,bytes,bytes))";

export function commandSelector(name: string): string {
  return ethers.dataSlice(ethers.id(name + COMMAND_ARGS), 0, 4);
}
