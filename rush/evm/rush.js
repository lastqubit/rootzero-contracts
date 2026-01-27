import { Contract } from "ethers";

const INJECT = "function inject(bytes[] steps) external payable returns(uint count)";
const EXECUTE = "function pipe(bytes[] steps, bytes signed) external payable returns(uint count)";

    // rush javascript -> pipe() factor() sign(steps).. or pipe.sign()
export function createRush(addr, provider) {
    const contract = new Contract(addr, [INJECT, EXECUTE], provider);

    async function inject(steps = []) {
        return contract.inject(steps, { value: 0n });
    }

    async function pipe(steps = [], signed = "0x") {
        return contract.pipe(steps, signed, { value: 0n });
    }

    return { inject, pipe };
}
