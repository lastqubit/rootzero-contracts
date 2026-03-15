import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner, getSigners } from "./helpers/setup.js";

describe("Validator", () => {
  let validator: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    validator = await deploy("TestValidator");
  });

  async function makeProof(signer: ethers.Signer, hash: string): Promise<string> {
    const addr = await signer.getAddress();
    const sig = await signer.signMessage(ethers.getBytes(hash));
    return ethers.concat([addr, sig]);
  }

  it("verifies valid proof and returns signer address", async () => {
    const signer = await getSigner(0);
    const hash = ethers.id("test payload");
    const proof = await makeProof(signer, hash);
    const result = await validator.testVerify.staticCall(hash, 0n, proof);
    expect(result.toLowerCase()).to.equal((await signer.getAddress()).toLowerCase());
  });

  it("reverts InvalidProof when proof is 84 bytes (too short)", async () => {
    const hash = ethers.id("test");
    const short = ethers.hexlify(new Uint8Array(84));
    await expect(validator.testVerify(hash, 0n, short))
      .to.be.revertedWithCustomError(validator, "InvalidProof");
  });

  it("reverts InvalidProof when proof is 86 bytes (too long)", async () => {
    const hash = ethers.id("test");
    const long = ethers.hexlify(new Uint8Array(86));
    await expect(validator.testVerify(hash, 0n, long))
      .to.be.revertedWithCustomError(validator, "InvalidProof");
  });

  it("reverts InvalidSigner when signer address does not match recovered address", async () => {
    const signer0 = await getSigner(0);
    const signer1 = await getSigner(1);
    const hash = ethers.id("test payload");
    const sig = await signer0.signMessage(ethers.getBytes(hash));
    // Construct proof with wrong signer address
    const wrongAddr = await signer1.getAddress();
    const proof = ethers.concat([wrongAddr, sig]);
    await expect(validator.testVerify(hash, 0n, proof))
      .to.be.revertedWithCustomError(validator, "InvalidSigner");
  });

  it("reverts InvalidSigner when signer address is zero", async () => {
    const signer = await getSigner(0);
    const hash = ethers.id("test");
    const sig = await signer.signMessage(ethers.getBytes(hash));
    const proof = ethers.concat([ethers.ZeroAddress, sig]);
    await expect(validator.testVerify(hash, 0n, proof))
      .to.be.revertedWithCustomError(validator, "InvalidSigner");
  });

  it("reverts NonceUsed on second use of same nonce", async () => {
    const signer = await getSigner(0);
    const hash = ethers.id("nonce reuse test");
    const proof = await makeProof(signer, hash);
    // First call succeeds
    await validator.testVerify(hash, 1n, proof);
    // Second call with same nonce and hash reverts
    await expect(validator.testVerify(hash, 1n, proof))
      .to.be.revertedWithCustomError(validator, "NonceUsed");
  });

  it("accepts different nonces for the same account", async () => {
    const signer = await getSigner(0);
    const hash = ethers.id("multi nonce test");
    const proof = await makeProof(signer, hash);
    await validator.testVerify(hash, 10n, proof);
    await validator.testVerify(hash, 11n, proof);
  });

  it("rejects reusing the same nonce even with a different hash", async () => {
    const signer = await getSigner(0);
    const proof1 = await makeProof(signer, ethers.id("payload one"));
    const proof2 = await makeProof(signer, ethers.id("payload two"));
    await validator.testVerify(ethers.id("payload one"), 12n, proof1);
    await expect(validator.testVerify(ethers.id("payload two"), 12n, proof2))
      .to.be.revertedWithCustomError(validator, "NonceUsed");
  });

  it("same nonce for different accounts do not conflict", async () => {
    const [s0, s1] = await getSigners(2);
    const hash = ethers.id("different accounts");
    const proof0 = await makeProof(s0, hash);
    const proof1 = await makeProof(s1, hash);
    await validator.testVerify(hash, 99n, proof0);
    await validator.testVerify(hash, 99n, proof1);
  });

  it("reverts InvalidSigner for a corrupted 65-byte signature", async () => {
    const signer = await getSigner(0);
    const hash = ethers.id("corrupted signature");
    const proof = await makeProof(signer, hash);
    const bytes = ethers.getBytes(proof);
    bytes[bytes.length - 1] ^= 0x01;
    await expect(validator.testVerify(hash, 200n, ethers.hexlify(bytes)))
      .to.be.revertedWithCustomError(validator, "InvalidSigner");
  });
});
