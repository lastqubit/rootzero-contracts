import { AbiCoder, FunctionFragment, dataLength, concat, zeroPadValue, toBeHex } from "ethers";
import { getDefaultValue } from "./defaults";

const abi = AbiCoder.defaultAbiCoder();

function getDefault(input, allow = false) {}

function toHex(value, length) {
    return zeroPadValue(toBeHex(value), length);
}

function toValues(inputs, args = {}) {
    return inputs.map((i) => args[i.name] ?? getDefaultValue(i.type));
}

export function encodeInputs(inputs, args = {}) {
    return abi.encode(inputs, toValues(inputs, args));
}

export function encodeCall(signature, args = {}) {
    const { inputs, selector } = FunctionFragment.from(signature);
    return concat([selector, abi.encode(inputs, toValues(inputs, args))]);
}

export function encodeBlock(key, inputs, args = {}) {
    const data = encodeInputs(inputs, args);
    const len = dataLength(data);
    return concat([toHex(key, 4), toHex(len, 4), data]);
}

export function encodeStep(eid, value = 0n, ...blocks) {
    return concat([toHex(eid, 32), toHex(value, 32), ...blocks.flat(Infinity)]);
}
