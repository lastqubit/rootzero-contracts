import { FunctionFragment } from "ethers";
import { encodeBlock, encodeStep } from "./encode";
import { validate } from "../schemas";
import { parseSignatures } from "./utils";

// uint indexed node, uint id, uint gas, string abi, string params
function toBlock(o) {
    const { name, clean } = o;
    const { inputs } = FunctionFragment.from(clean);
    return [name, { ...o, inputs }];
}
// -> key, name, category, signature, clean, rules, inputs

export function mapBlocks(...signatures) {
    return new Map(parseSignatures(signatures).map(toBlock));
}

export function createEndpoint({ node, id, gas, abi, params }) {
    const composers = new Map(parseSignatures(params).map(toBlockComposer));
    const blocks = {};

    function toBlockComposer({ key, name, clean, rules }) {
        const { inputs } = FunctionFragment.from(clean);
        function compose(args = {}) {
            validate(inputs, rules, args);
            blocks[name] = encodeBlock(key, inputs, args);
            return endpoint;
        }
        return [name, compose];
    }

    function step(value = 0n) {
        const temp = [];
        for (const [key] of composers) {
            if (key in blocks) {
                temp.push(blocks[key]);
            }
        }
        return encodeStep(id, value, temp);
    }

    const endpoint = {
        id,
        abi,
        node,
        gas,
        step,
        ...Object.fromEntries(composers),
    };

    return endpoint;
}
