import fs from "fs";
import path from "path";
import yazl from "yazl";
import { getPackageVersion } from "./utils.mjs";

const version = getPackageVersion();

const distDir = path.resolve("dist");
const zipPath = path.join(distDir, `BorderlessToggle-${version}.zip`);
const appExe = path.resolve("build", "BorderlessToggle.exe");
const licenseFile = path.resolve("LICENSE");

if (!fs.existsSync(appExe)) {
  throw new Error("Missing executable. Run 'npm run compile' first.");
}

if (!fs.existsSync(licenseFile)) {
  throw new Error(`Missing file: ${licenseFile}`);
}

fs.mkdirSync(distDir, { recursive: true });
if (fs.existsSync(zipPath)) {
  fs.rmSync(zipPath, { force: true });
}

const zip = new yazl.ZipFile();
zip.addFile(appExe, "BorderlessToggle.exe");
zip.addFile(licenseFile, "LICENSE");

zip.end();

await new Promise((resolve, reject) => {
  zip.outputStream.pipe(fs.createWriteStream(zipPath)).on("close", resolve).on("error", reject);
});

console.log(`Created ${zipPath}`);
