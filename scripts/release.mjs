import fs from "fs";
import path from "path";
import { execFileSync } from "child_process";
import { getPackageVersion } from "./utils.mjs";

const version = getPackageVersion();

const zipPath = path.resolve("dist", `BorderlessToggle-${version}.zip`);
const repo = "starise/borderless-toggle";

if (!fs.existsSync(zipPath)) {
  throw new Error(`Missing release archive: ${zipPath}. Run 'pnpm run build' first.`);
}

try {
  execFileSync("gh", ["auth", "status"], { stdio: "ignore" });
} catch {
  throw new Error(
    "GitHub CLI is not authenticated. Run 'gh auth login' or set the GH_TOKEN environment variable, then retry.",
  );
}

try {
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
} catch (error) {
  const details =
    error instanceof Error && error.message
      ? error.message
      : "Unknown error while creating GitHub release.";

  throw new Error(`Release failed for ${repo}@${version}: ${details}`);
}
