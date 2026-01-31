import { id } from "ethers";
import { max32, max160 } from "../utils";

function buildId(addr, selector, chain, desc) {
    let id = max160(addr);
    id |= max32(chain) << 160n;
    id |= max32(desc) << 192n;
    id |= max32(selector) << 224n;
    return id;
}

export function getSelector(signature) {
    return id(signature).slice(0, 10);
}

// Parse "event Balance:Transfer(uint account:positive, uint amount)"
// → { name: "Balance", category: "Transfer", clean: "event Balance(uint account, uint amount)", rules: { account: ["positive"] } }
export function parseSignature(signature) {
    const match = signature?.match(/^(?:\w+\s+)*(\w+)(?::(\w+))?\s*\(.*\)$/);
    if (!match) throw new Error("Invalid signature: " + signature);

    const key = id(signature).slice(0, 10);
    const name = match[1];
    const category = match[2] || name;

    // Strip category colon from signature
    let clean = match[2] ? signature.replace(`${name}:${category}`, name) : signature;

    // Extract rules from parameter annotations
    const rules = {};
    clean = clean.replace(/(\w+)(:\w+(?:\([^)]*\))?)+/g, (m, param) => {
        rules[param] = m.split(":").slice(1);
        return param;
    });

    return { key, name, category, signature, clean, rules };
}

export function splitSignatures(...signatures) {
    return signatures.flat(Infinity).flatMap((s) => s.split(";"));
}

export function parseSignatures(...signatures) {
    return splitSignatures(signatures).map(parseSignature);
}
