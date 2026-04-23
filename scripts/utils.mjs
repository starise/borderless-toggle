import fs from "fs";
import path from "path";

export function getPackageVersion() {
  const pkgPath = path.resolve("package.json");
  const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf-8"));

  if (!pkg.version) {
    throw new Error("Missing version in package.json");
  }

  return pkg.version;
}
