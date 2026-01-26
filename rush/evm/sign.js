import { getBytes, keccak256 } from "ethers";

export async function signData(data, signer) {
    const hash = keccak256(getBytes(data));
    const signature = await signer.signMessage(getBytes(hash));
    return { hash, signature };
}

/* // Usage
const wallet = new Wallet('YOUR_PRIVATE_KEY');

// Can pass hex string or Uint8Array
const data = '0x1234567890abcdef';
// or
// const data = new Uint8Array([0x12, 0x34, 0x56, 0x78]);

const { hash, signature } = await signData(data, wallet);

console.log('Data:', data);
console.log('Hash:', hash);
console.log('Signer:', wallet.address);
console.log('Signature:', signature);

// To verify in your contract:
// isSigned(hash, wallet.address, signature) should return true */
