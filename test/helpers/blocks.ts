import { ethers } from "ethers";

// Block key derivation: bytes4(keccak256("#name"))
export function blockKey(name: string): string {
  return ethers.dataSlice(ethers.id(name), 0, 4);
}

export function localKey(value: number): string {
  return ethers.toBeHex(value, 4);
}

export function exactSpec(key: string, size: number): bigint {
  const value = BigInt(size);
  return (BigInt(key) << 224n) | (value << 192n) | (value << 160n) | (value << 136n);
}

export function rangedSpec(key: string, min: number, max: number, hint: number): bigint {
  return (BigInt(key) << 224n)
    | (BigInt(min) << 192n)
    | (BigInt(max) << 160n)
    | (BigInt(hint) << 136n);
}

function laneStride(lane: string, stride?: number): number {
  const value = stride ?? 0;
  return value === 0 && BigInt(lane) !== 0n ? 1 : value;
}

export function endpointDescriptor({
  state = Keys.Empty,
  stateStride,
  input = Keys.Empty,
  inputStride,
  output = Keys.Empty,
  outputStride,
  funded = false,
  admin = false,
  handoff = false,
}: {
  state?: string;
  stateStride?: number;
  input?: string;
  inputStride?: number;
  output?: string | bigint;
  outputStride?: number;
  funded?: boolean;
  admin?: boolean;
  handoff?: boolean;
}): bigint {
  const flags = (funded ? 1n : 0n) | (admin ? 2n : 0n) | (handoff ? 128n : 0n);
  const stateLaneStride = laneStride(state, stateStride);
  const inputLaneStride = laneStride(input, inputStride);
  const outputSpec = typeof output === "bigint"
    ? output
    : output === Keys.Empty
      ? 0n
      : (() => { throw new Error("non-empty output lanes require a spec"); })();
  const encodedOutputStride = outputStride
    ?? (typeof output === "bigint" ? Number((output >> 128n) & 0xffn) : 0);
  const outputLaneStride = encodedOutputStride === 0 && outputSpec !== 0n
    ? 1
    : encodedOutputStride;
  const stateLane = (BigInt(state) << 8n) | BigInt(stateLaneStride);
  const inputLane = (BigInt(input) << 8n) | BigInt(inputLaneStride);
  const outputLane = ((outputSpec >> 128n) & ~0xffn) | BigInt(outputLaneStride);
  const descriptor =
    (stateLane << 216n) |
    (inputLane << 176n) |
    (outputLane << 48n) |
    flags;

  return descriptor;
}

// Known block keys
export const Keys = {
  Empty: "0x00000000",
  Local: localKey(1),
  Bootstrap: blockKey("#bootstrap"),
  Amount: blockKey("#amount"),
  Balance: blockKey("#balance"),
  Debt: blockKey("#debt"),
  Allocation: blockKey("#allocation"),
  Allowance: blockKey("#allowance"),
  Custody: blockKey("#custody"),
  Position: blockKey("#position"),
  Account: blockKey("#account"),
  Node: blockKey("#node"),
  Asset: blockKey("#asset"),
  Step: blockKey("#step"),
  Call: blockKey("#call"),
  Context: blockKey("#context"),
  Recover: blockKey("#recover"),
  Relay: blockKey("#relay"),
  Dispatch: blockKey("#dispatch"),
  Transaction: blockKey("#transaction"),
  Label: blockKey("#label"),
  Annotation: blockKey("#annotation"),
  Action: blockKey("#action"),
  Schema: blockKey("#schema"),
  Bytes: blockKey("#bytes"),
  String: blockKey("#string"),
  List: blockKey("#list"),
  Evm: blockKey("#evm"),
  Status: blockKey("#status"),
  AccountAsset: blockKey("#accountAsset"),
  HostAsset: blockKey("#hostAsset"),
  AccountAmount: blockKey("#accountAmount"),
  HostAmount: blockKey("#hostAmount"),
  HostAccountAsset: blockKey("#hostAccountAsset"),
  HostAccountAmount: blockKey("#hostAccountAmount"),
} as const;

// Pad a bigint or hex string to 32 bytes
export function pad32(value: bigint | string): string {
  if (typeof value === "bigint") {
    return ethers.zeroPadValue(ethers.toBeHex(value), 32);
  }
  return ethers.zeroPadValue(value, 32);
}

const USER_PREFIX = 0x01010300n;

export function encodeUserAccount(addr: string): string {
  const account = (USER_PREFIX << 224n) | (BigInt(ethers.zeroPadValue(addr, 20)) << 32n);
  return ethers.zeroPadValue(ethers.toBeHex(account), 32);
}

// Encode a 4-byte big-endian uint32
function encodeUint32(value: number): string {
  return ethers.toBeHex(value, 4);
}

// Build a block header + payload
export function encodeBlock(key: string, payload: string): string {
  const payloadBytes = ethers.getBytes(payload);
  return ethers.concat([key, encodeUint32(payloadBytes.length), payload]);
}

export function encodeAmountBlock(asset: string, amount: bigint): string {
  return encodeBlock(Keys.Amount, ethers.concat([pad32(asset), pad32(amount)]));
}

export function encodeBootstrapBlock(asset: string, amount: bigint, budget: bigint): string {
  return encodeBlock(Keys.Bootstrap, ethers.concat([pad32(asset), pad32(amount), pad32(budget)]));
}

export function encodeBalanceBlock(asset: string, amount: bigint): string {
  return encodeBlock(Keys.Balance, ethers.concat([pad32(asset), pad32(amount)]));
}

export function encodeDebtBlock(liability: string, debt: bigint): string {
  return encodeBlock(Keys.Debt, ethers.concat([pad32(liability), pad32(debt)]));
}

export function encodeHostAccountAssetBlock(host: bigint, account: string, asset: string): string {
  return encodeBlock(Keys.HostAccountAsset, ethers.concat([pad32(host), pad32(account), pad32(asset)]));
}

export function encodeAccountAssetBlock(account: string, asset: string): string {
  return encodeBlock(Keys.AccountAsset, ethers.concat([pad32(account), pad32(asset)]));
}

export function encodeHostAssetBlock(host: bigint, asset: string): string {
  return encodeBlock(Keys.HostAsset, ethers.concat([pad32(host), pad32(asset)]));
}

export function encodeAccountAmountBlock(account: string, asset: string, amount: bigint): string {
  return encodeBlock(Keys.AccountAmount, ethers.concat([pad32(account), pad32(asset), pad32(amount)]));
}

export function encodeAllocationBlock(host: bigint, asset: string, amount: bigint): string {
  return encodeBlock(Keys.Allocation, ethers.concat([pad32(host), pad32(asset), pad32(amount)]));
}

export function encodeAllowanceBlock(host: bigint, asset: string, amount: bigint): string {
  return encodeBlock(Keys.Allowance, ethers.concat([pad32(host), pad32(asset), pad32(amount)]));
}

export function encodeCustodyBlock(host: bigint, asset: string, amount: bigint): string {
  return encodeBlock(Keys.Custody, ethers.concat([pad32(host), pad32(asset), pad32(amount)]));
}

export function encodePositionBlock(
  asset: string,
  amount: bigint,
  liability: string,
  debt: bigint,
): string {
  return encodeBlock(Keys.Position, ethers.concat([
    pad32(asset),
    pad32(amount),
    pad32(liability),
    pad32(debt),
  ]));
}

export function encodeAccountBlock(account: string): string {
  return encodeBlock(Keys.Account, pad32(account));
}

export function encodeNodeBlock(id: bigint): string {
  return encodeBlock(Keys.Node, pad32(id));
}

export function encodeAssetBlock(asset: string): string {
  return encodeBlock(Keys.Asset, pad32(asset));
}

export function encodeTxBlock(from: string, to: string, asset: string, amount: bigint): string {
  return encodeBlock(Keys.Transaction, ethers.concat([pad32(from), pad32(to), pad32(asset), pad32(amount)]));
}

export function encodeStepBlock(cmd: bigint, value: bigint, input: string): string {
  return encodeBlock(Keys.Step, ethers.concat([
    pad32(cmd),
    pad32(value),
    encodeBytesBlock(input),
  ]));
}

export function encodeCallBlock(target: bigint, value: bigint, data: string): string {
  return encodeBlock(Keys.Call, ethers.concat([pad32(target), pad32(value), encodeBytesBlock(data)]));
}

export function encodeContextBlock(account: string, state: string, input: string): string {
  return encodeBlock(Keys.Context, ethers.concat([pad32(account), encodeBytesBlock(state), encodeBytesBlock(input)]));
}

export function encodeRecoverBlock(handler: bigint, resources: bigint, key: string, witness: string): string {
  return encodeBlock(Keys.Recover, ethers.concat([pad32(handler), pad32(resources), pad32(key), encodeBytesBlock(witness)]));
}

export function encodeRelayBlock(input: string, steps: string): string;
export function encodeRelayBlock(portal: bigint, resources: bigint, steps: string): string;
export function encodeRelayBlock(inputOrPortal: string | bigint, stepsOrResources: string | bigint, steps?: string): string {
  const input = typeof inputOrPortal === "bigint"
    ? ethers.concat([pad32(inputOrPortal), pad32(stepsOrResources as bigint)])
    : inputOrPortal;
  const continuation = steps ?? (stepsOrResources as string);
  return encodeBlock(Keys.Relay, ethers.concat([encodeBytesBlock(input), encodeBytesBlock(continuation)]));
}

export function encodeDispatchBlock(portal: bigint, resources: bigint, payload: string): string {
  return encodeBlock(Keys.Dispatch, ethers.concat([pad32(portal), pad32(resources), encodeBytesBlock(payload)]));
}

export function encodeBytesBlock(data: string): string {
  return encodeBlock(Keys.Bytes, data);
}

export function encodeStringBlock(data: string): string {
  return encodeBlock(Keys.String, ethers.hexlify(ethers.toUtf8Bytes(data)));
}

export function encodeLabelBlock(namespace: string, name: string): string {
  return encodeBlock(Keys.Label, ethers.concat([pad32(namespace), encodeStringBlock(name)]));
}

export function encodeAnnotationBlock(entity: bigint, data: string): string {
  return encodeBlock(Keys.Annotation, ethers.concat([pad32(entity), encodeBytesBlock(data)]));
}

export function encodeActionBlock(action: bigint): string {
  return encodeBlock(Keys.Action, pad32(action));
}

export function encodeSchemaBlock(spec: bigint, body: string, name: string): string {
  return encodeBlock(Keys.Schema, ethers.concat([pad32(spec), encodeStringBlock(body), pad32(name)]));
}

export function encodeEvmBlock(data: string): string {
  return encodeBlock(Keys.Evm, data);
}

export function encodeStatusBlock(code: bigint): string {
  return encodeBlock(Keys.Status, pad32(code));
}

export function encodeListBlock(...members: string[]): string {
  return encodeBlock(Keys.List, concat(...members));
}

export function concat(...parts: string[]): string {
  return ethers.concat(parts);
}

// Command args suffix appended when computing command selectors
const COMMAND_ARGS = "(bytes)";
const PORT_ARGS = "(bytes)";
const GUARD_ARGS = "(bytes)";

export function commandSelector(name: string): string {
  return ethers.dataSlice(ethers.id(name + COMMAND_ARGS), 0, 4);
}

export function portSelector(name: string): string {
  return ethers.dataSlice(ethers.id(name + PORT_ARGS), 0, 4);
}

export function guardSelector(name: string): string {
  return ethers.dataSlice(ethers.id(name + GUARD_ARGS), 0, 4);
}

