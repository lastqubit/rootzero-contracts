import { Interface, AbiCoder } from "ethers";

function parseAndEncode(signature, paramValues) {
    // Normalize signature - remove 'function' keyword if present
    const normalizedSignature = signature.trim().replace(/^function\s+/, "");

    // Create interface and get fragment
    const iface = new Interface([`function ${normalizedSignature}`]);

    // Extract function name from signature
    const functionName = normalizedSignature.match(/^(\w+)\(/)[1];
    const fragment = iface.getFunction(functionName);

    // Extract parameter types from fragment.inputs
    const paramTypes = fragment.inputs.map((input) => input.type);

    // Encode using AbiCoder
    const abiCoder = AbiCoder.defaultAbiCoder();
    const encodedParams = abiCoder.encode(paramTypes, paramValues);

    return {
        fragment,
        paramTypes,
        encodedParams,
    };
}

// Usage - works with or without 'function' keyword
const sig1 = "debitFrom(uint use, uint min, uint max, uint bounty)";
const sig2 = "function debitFrom(uint use, uint min, uint max, uint bounty)";

const result = parseAndEncode(sig1, [100n, 50n, 200n, 10n]);
console.log("Parameter types:", result.paramTypes);
console.log("Encoded params:", result.encodedParams);
