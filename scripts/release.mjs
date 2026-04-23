import fs from "fs";
import path from "path";
import { execFileSync } from "child_process";
import { getPackageVersion } from "./utils.mjs";

const version = getPackageVersion();

const zipPath = path.resolve("dist", `BorderlessToggle-${version}.zip`);
const repo = "git@github.com:starise/borderless-toggle.git";

if (!fs.existsSync(zipPath)) {
  throw new Error(`Missing release archive: ${zipPath}. Run 'npm run build' first.`);
}

execFileSync(
  "gh",
  [
    "release",
    "create",
    version,
    zipPath,
    "--repo",
    repo,
    "--title",
    `Release v${version}`,
    "--notes",
    `Release version ${version}`,
  ],
  { stdio: "inherit" },
);
