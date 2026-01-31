import { z } from "zod";

const isBytes = (v) => typeof v === "string" && /^0x[0-9a-fA-F]*$/.test(v);

function toBaseSchema(type) {
    if (type === "bool") return z.boolean();
    if (type === "string") return z.string();
    if (type === "address") return z.string().regex(/^0x[0-9a-fA-F]{40}$/, "invalid address");
    if (type === "bytes") return z.string().refine(isBytes, "invalid bytes");
    if (type.startsWith("bytes")) return z.string().refine(isBytes, `invalid ${type}`);
    if (type.endsWith("[]")) return z.array(toBaseSchema(type.slice(0, -2)));
    if (type.startsWith("uint") || type.startsWith("int")) return z.bigint();
    return z.any();
}

function parseRule(rule) {
    const match = rule.match(/^(\w+)(?:\(([^)]*)\))?$/);
    if (!match) throw new Error(`Invalid rule: ${rule}`);
    return { name: match[1], arg: match[2] };
}

function applyRule(schema, { name, arg }, paramName, args) {
    switch (name) {
        case "positive":
            return schema.refine((v) => v > 0n, `${paramName} must be positive`);
        case "nonzero":
            return schema.refine((v) => v !== 0n && v !== 0 && v !== "", `${paramName} must be nonzero`);
        case "gt":
            return schema.refine((v) => v > BigInt(args[arg] ?? 0), `${paramName} must be > ${arg}`);
        case "gte":
            return schema.refine((v) => v >= BigInt(args[arg] ?? 0), `${paramName} must be >= ${arg}`);
        case "lt":
            return schema.refine((v) => v < BigInt(args[arg] ?? 0), `${paramName} must be < ${arg}`);
        case "lte":
            return schema.refine((v) => v <= BigInt(args[arg] ?? 0), `${paramName} must be <= ${arg}`);
        case "nonempty":
            return schema.refine((v) => v.length > 0, `${paramName} must be nonempty`);
        default:
            throw new Error(`Unknown rule: ${name} on ${paramName}`);
    }
}

export function validate(inputs, rules, args = {}) {
    const shape = {};
    for (const input of inputs) {
        const { name, type } = input;
        let schema = toBaseSchema(type);
        const paramRules = rules[name];
        if (paramRules) {
            const isOptional = paramRules.includes("optional");
            for (const rule of paramRules) {
                if (rule === "optional") continue;
                schema = applyRule(schema, parseRule(rule), name, args);
            }
            if (isOptional) schema = schema.optional();
        }
        shape[name] = schema;
    }

    const result = z.object(shape).strict().safeParse(args);
    if (!result.success) {
        const msg = result.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join(", ");
        throw new Error(msg);
    }
}
