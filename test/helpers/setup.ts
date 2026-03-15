import hre from "hardhat";
import { ethers } from "ethers";

let _connection: Awaited<ReturnType<typeof hre.network.connect>> | null = null;

async function getConnection() {
  if (!_connection) {
    _connection = await hre.network.connect();
  }
  return _connection;
}

export async function getProvider() {
  const conn = await getConnection();
  return new ethers.BrowserProvider(conn.provider);
}

export async function getSigner(index = 0) {
  const provider = await getProvider();
  return provider.getSigner(index);
}

export async function getSigners(count = 5) {
  const provider = await getProvider();
  const accounts = await provider.listAccounts();
  return Promise.all(accounts.slice(0, count).map((_, i) => provider.getSigner(i)));
}

export async function deploy(contractName: string, ...args: unknown[]) {
  const signer = await getSigner();
  const artifact = await hre.artifacts.readArtifact(contractName);
  const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, signer);
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();
  return contract;
}

export async function deployAs(signerIndex: number, contractName: string, ...args: unknown[]) {
  const signer = await getSigner(signerIndex);
  const artifact = await hre.artifacts.readArtifact(contractName);
  const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, signer);
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();
  return contract;
}
