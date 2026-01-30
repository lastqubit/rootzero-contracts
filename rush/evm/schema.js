import { z } from "zod";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const RULE_RE = /^(\w+)(?:\(([^)]*)\))?$/;

function parseRule(rule) {
    const match = rule.match(RULE_RE);
    if (!match) return null;
    return { name: match[1], arg: match[2] ?? null };
}

function isFieldRef(arg, fieldNames) {
    return arg !== null && fieldNames.has(arg);
}

function zodType(type) {
    if (type.endsWith("[]")) {
        const inner = zodType(type.slice(0, -2));
        return z.array(inner);
    }
    if (type.startsWith("uint")) return z.bigint().nonnegative();
    if (type.startsWith("int")) return z.bigint();
    if (type === "address") return z.string().regex(/^0x[0-9a-fA-F]{40}$/, "Invalid address");
    if (type === "bool") return z.boolean();
    if (type === "string") return z.string();
    if (type === "bytes") return z.string().startsWith("0x");
    if (type.startsWith("bytes")) {
        const size = parseInt(type.replace("bytes", ""));
        return z.string().length(2 + size * 2).startsWith("0x");
    }
    return z.any();
}

function applyRule(schema, rule, type) {
    const { name, arg } = rule;
    const isBigint = type.startsWith("uint") || type.startsWith("int");
    const isArray = type.endsWith("[]");

    switch (name) {
        case "positive":
            return isBigint ? schema.refine((v) => v > 0n, { message: "Must be positive" }) : schema;
        case "min":
            return isBigint ? schema.refine((v) => v >= BigInt(arg), { message: `Must be >= ${arg}` }) : schema;
        case "max":
            return isBigint ? schema.refine((v) => v <= BigInt(arg), { message: `Must be <= ${arg}` }) : schema;
        case "gt":
            return isBigint ? schema.refine((v) => v > BigInt(arg), { message: `Must be > ${arg}` }) : schema;
        case "gte":
            return isBigint ? schema.refine((v) => v >= BigInt(arg), { message: `Must be >= ${arg}` }) : schema;
        case "lt":
            return isBigint ? schema.refine((v) => v < BigInt(arg), { message: `Must be < ${arg}` }) : schema;
        case "lte":
            return isBigint ? schema.refine((v) => v <= BigInt(arg), { message: `Must be <= ${arg}` }) : schema;
        case "nonzero":
            if (type === "address") return schema.refine((v) => v !== ZERO_ADDRESS, { message: "Must not be zero address" });
            if (isBigint) return schema.refine((v) => v !== 0n, { message: "Must not be zero" });
            return schema;
        case "nonempty":
            return isArray ? schema.min(1, { message: "Must not be empty" }) : schema;
        case "length":
            return isArray ? schema.length(parseInt(arg)) : schema;
        case "optional":
            return schema.optional();
        default:
            return schema;
    }
}

// Parse "debitFrom(uint use:positive, uint min, uint max:gte(min))"
// → { clean: "debitFrom(uint use, uint min, uint max)", rules: { use: ["positive"], max: ["gte(min)"] } }
export function parseParams(params) {
    const openParen = params.indexOf("(");
    const closeParen = params.lastIndexOf(")");
    if (openParen === -1 || closeParen === -1) return { clean: params, rules: {} };

    const funcName = params.slice(0, openParen);
    const inner = params.slice(openParen + 1, closeParen);
    const rules = {};
    const cleanParts = [];

    for (const part of inner.split(",")) {
        const trimmed = part.trim();
        if (!trimmed) continue;

        // Split "uint use:positive:min(1)" → ["uint", "use:positive:min(1)"]
        const tokens = trimmed.split(/\s+/);
        const type = tokens[0];
        const nameWithRules = tokens[1] || "";
        const segments = nameWithRules.split(":");
        const fieldName = segments[0];
        const fieldRules = segments.slice(1).filter(Boolean);

        if (fieldRules.length > 0) {
            rules[fieldName] = fieldRules;
        }

        cleanParts.push(`${type} ${fieldName}`);
    }

    const clean = `${funcName}(${cleanParts.join(", ")})`;
    return { clean, rules };
}

export function buildSchema(schema, rules = {}) {
    const fieldNames = new Set(schema.map((f) => f.name));
    const shape = {};
    const refinements = [];

    for (const { name, type } of schema) {
        let fieldSchema = zodType(type);
        const fieldRules = rules[name] || [];

        for (const ruleStr of fieldRules) {
            const rule = parseRule(ruleStr);
            if (!rule) continue;

            // Cross-field reference → object-level refinement
            if (rule.arg && isFieldRef(rule.arg, fieldNames)) {
                const refField = rule.arg;
                const op = rule.name;
                refinements.push({
                    check: (data) => {
                        const a = data[name];
                        const b = data[refField];
                        if (a === undefined || b === undefined) return true;
                        switch (op) {
                            case "gt": return a > b;
                            case "gte": return a >= b;
                            case "lt": return a < b;
                            case "lte": return a <= b;
                            default: return true;
                        }
                    },
                    message: `${name} must be ${rule.name} ${refField}`,
                    path: [name],
                });
                continue;
            }

            fieldSchema = applyRule(fieldSchema, rule, type);
        }

        shape[name] = fieldSchema;
    }

    let objectSchema = z.object(shape);

    for (const ref of refinements) {
        objectSchema = objectSchema.refine(ref.check, { message: ref.message, path: ref.path });
    }

    return objectSchema;
}
