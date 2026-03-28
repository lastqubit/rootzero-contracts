import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, "..");
const outDir = path.join(root, "dist", "package");
const contractsDir = path.join(root, "contracts");

const pkg = JSON.parse(await readFile(path.join(root, "package.json"), "utf8"));

await rm(outDir, { recursive: true, force: true });
await mkdir(outDir, { recursive: true });

// Flatten the published package by copying the contents of contracts/ into
// the package root while preserving relative imports inside the tree.
// Exclude internal test contracts from the published artifact.
await cp(contractsDir, outDir, {
  recursive: true,
  filter(source) {
    const relative = path.relative(contractsDir, source);
    return relative === "" || (!relative.startsWith(`test${path.sep}`) && relative !== "test");
  }
});
await cp(path.join(root, "README.md"), path.join(outDir, "README.md"));
await cp(path.join(root, "LICENSE"), path.join(outDir, "LICENSE"));

const outPkg = {
  name: pkg.name,
  version: pkg.version,
  description: pkg.description,
  private: false,
  license: pkg.license,
  type: pkg.type,
  files: ["**/*.sol", "README.md", "LICENSE"],
  publishConfig: pkg.publishConfig
};

await writeFile(path.join(outDir, "package.json"), `${JSON.stringify(outPkg, null, 2)}\n`);
