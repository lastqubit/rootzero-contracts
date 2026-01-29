import { AbiCoder, FunctionFragment, dataLength, concat, zeroPadValue, toBeHex } from "ethers";
import { getDefaultValue } from "./defaults";
import { getSelector } from "./utils";

const abi = AbiCoder.defaultAbiCoder();

function getDefault(input, allow = false) {}

function toHex(value, length) {
    return zeroPadValue(toBeHex(value), length);
}

function toValues(inputs, args = {}) {
    return inputs.map((i) => args[i.name] ?? getDefaultValue(i.type));
}

export function encodeInputs(signature, args = {}) {
    const { inputs } = FunctionFragment.from(signature);
    return abi.encode(inputs, toValues(inputs, args));
}

export function encodeCall(signature, args = {}) {
    const { inputs, selector } = FunctionFragment.from(signature);
    return concat([selector, abi.encode(inputs, toValues(inputs, args))]);
}

export function encodeBlock(signature, args = {}) {
    const key = getSelector(signature);
    const data = encodeInputs(signature, args);
    const len = toHex(dataLength(data), 4);
    return concat([key, len, data]);
}

export function encodeStep(eid, value = 0n, ...blocks) {
    return concat([toHex(eid, 32), toHex(value, 32), ...blocks]);
}
