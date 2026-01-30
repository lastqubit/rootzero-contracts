import { FunctionFragment } from "ethers";
import { parseParams } from "./evm/schema.js";

const TYPE_MAP = {
    address: "string",
    bool: "boolean",
    string: "string",
    bytes: "string",
};

function toJSType(solType) {
    if (solType.endsWith("[]")) return `${toJSType(solType.slice(0, -2))}[]`;
    if (solType.startsWith("uint") || solType.startsWith("int")) return "bigint";
    if (solType.startsWith("bytes")) return "string";
    return TYPE_MAP[solType] ?? "any";
}

function toJSDocParam(schema, rules) {
    const fields = schema.map(({ name, type }) => {
        const jsType = toJSType(type);
        const fieldRules = rules[name] || [];
        const optional = fieldRules.includes("optional") ? "?" : "";
        return `${name}${optional}: ${jsType}`;
    });
    return `{ ${fields.join(", ")} }`;
}

function generateBlock(blockName, signature, schema, rules, endpointName, eid) {
    const paramType = toJSDocParam(schema, rules);
    const lines = [];

    lines.push(`/**`);
    lines.push(` * Encode a ${blockName} block for the ${endpointName} endpoint`);
    lines.push(` * @param {${paramType}} args`);
    lines.push(` * @returns {string} Encoded block bytes`);
    lines.push(` */`);
    lines.push(`export function ${blockName}(args = {}) {`);
    lines.push(`    return encodeBlock("${signature}", args);`);
    lines.push(`}`);
    lines.push(``);

    lines.push(`/**`);
    lines.push(` * Encode a full ${blockName} step for the ${endpointName} endpoint`);
    lines.push(` * @param {${paramType}} args`);
    lines.push(` * @returns {string} Encoded step bytes`);
    lines.push(` */`);
    lines.push(`export function ${blockName}Step(args = {}) {`);
    lines.push(`    return encodeStep(${endpointName}Id, 0n, ${blockName}(args));`);
    lines.push(`}`);

    return lines.join("\n");
}

function generateEndpoint(ep) {
    const { abi } = ep;
    const { name: endpointName } = FunctionFragment.from(abi);
    const lines = [];

    lines.push(`/** @type {bigint} Endpoint ID for ${endpointName} */`);
    lines.push(`export const ${endpointName}Id = ${ep.id}n;`);
    lines.push(``);

    if (!ep.params) return lines.join("\n");

    const sigs = ep.params.split(";").map((s) => s.trim()).filter(Boolean);

    for (const sig of sigs) {
        const { clean, rules } = parseParams(sig);
        const fragment = FunctionFragment.from(clean);
        const schema = fragment.inputs.map((i) => ({ name: i.name, type: i.type }));
        lines.push(generateBlock(fragment.name, clean, schema, rules, endpointName, ep.id));
        lines.push(``);
    }

    return lines.join("\n");
}

/**
 * Generate a typed JS module from endpoint event data.
 * @param {Array<{ id: bigint, node: bigint, gas: bigint, abi: string, params: string }>} endpoints
 * @param {{ addr?: string, name?: string }} options
 * @returns {string} Generated JS source code
 */
export function generate(endpoints, { addr, name, importPath = "../evm/encode.js" } = {}) {
    const lines = [];
    const label = name || addr || "contract";

    lines.push(`// @generated from ${label}${addr ? ` at ${addr}` : ""}`);
    lines.push(`import { encodeBlock, encodeStep } from "${importPath}";`);
    lines.push(``);

    for (const ep of endpoints) {
        lines.push(generateEndpoint(ep));
    }

    return lines.join("\n");
}
