import { FunctionFragment } from "ethers";
import { parseFunctions } from "./utils.js";
import { encodeBlock, encodeStep } from "./encode.js";
import { buildSchema } from "./schema.js";

function toSchema(fragment) {
    return fragment.inputs.map((i) => ({ name: i.name, type: i.type }));
}

function getName(abi, fragment) {
    if (fragment) return fragment.name;
    const { name } = FunctionFragment.from(abi);
    return name;
}

export function createEndpoint({ id, node, gas, abi, params }) {
    const blocks = params ? parseFunctions(params) : {};
    const entry = Object.values(blocks)[0] ?? null;
    const request = entry?.fragment ?? null;
    const rules = entry?.rules ?? {};
    const name = getName(abi, request);
    const schema = request ? toSchema(request) : [];
    const zodSchema = request ? buildSchema(schema, rules) : null;

    const signature = entry?.signature ?? null;

    function encode(args = {}) {
        if (!signature) return encodeStep(id, 0n);
        const b = encodeBlock(signature, args);
        return encodeStep(id, 0n, b);
    }

    function block(args = {}) {
        if (!signature) return "0x";
        return encodeBlock(signature, args);
    }

    function validate(args = {}) {
        if (!zodSchema) return { success: true, data: args };
        return zodSchema.safeParse(args);
    }

    const endpoint = { id, node, name, gas, abi, params, schema, blocks, zodSchema, encode, block, validate };

    return new Proxy(endpoint, {
        get(target, prop) {
            if (prop in target) return target[prop];
            if (prop in blocks) {
                const { signature } = blocks[prop];
                return (args = {}) => encodeBlock(signature, args);
            }
        },
    });
}
