import fs from "fs";
import path from "path";
import { execFileSync } from "child_process";

const toolsDir = path.resolve(".tools");
const cacheDir = path.resolve(".cache", "tools");
const force = process.argv.includes("--force");

const tools = [
  {
    name: "AutoHotkey v2",
    outputName: "AutoHotkey64.exe",
    source: "https://www.autohotkey.com/download/ahk-v2.zip",
    match: (file) => path.basename(file).toLowerCase() === "autohotkey64.exe",
  },
  {
    name: "Ahk2Exe",
    outputName: "Ahk2Exe.exe",
    source: () =>
      githubLatestAsset("AutoHotkey", "Ahk2Exe", (asset) => /^Ahk2Exe.*\.zip$/i.test(asset.name)),
    match: (file) => path.basename(file).toLowerCase() === "ahk2exe.exe",
  },
  {
    name: "UPX",
    outputName: "Upx.exe",
    source: () => githubLatestAsset("upx", "upx", (asset) => /win64.*\.zip$/i.test(asset.name)),
    match: (file) => path.basename(file).toLowerCase() === "upx.exe",
  },
];

if (process.platform !== "win32") {
  throw new Error("This setup script is Windows-only.");
}

fs.mkdirSync(toolsDir, { recursive: true });
fs.mkdirSync(cacheDir, { recursive: true });

for (const tool of tools) {
  await ensureTool(tool);
}

async function ensureTool(tool) {
  const outputPath = path.join(toolsDir, tool.outputName);

  if (!force && fs.existsSync(outputPath)) {
    console.log(`OK  ${tool.outputName} already exists`);
    return;
  }

  console.log(`Getting ${tool.name}...`);

  const url = typeof tool.source === "function" ? await tool.source() : tool.source;
  const archivePath = path.join(cacheDir, `${tool.outputName}.zip`);
  const extractDir = path.join(cacheDir, `${path.basename(tool.outputName, ".exe")}-extract`);

  await downloadFile(url, archivePath);
  extractZip(archivePath, extractDir);

  const sourceExe = findFile(extractDir, tool.match);
  if (!sourceExe) {
    throw new Error(`Could not find ${tool.outputName} inside ${archivePath}`);
  }

  fs.copyFileSync(sourceExe, outputPath);
  console.log(`OK  ${tool.outputName}`);
}

async function githubLatestAsset(owner, repo, predicate) {
  const release = await fetchJson(`https://api.github.com/repos/${owner}/${repo}/releases/latest`);
  const asset = release.assets.find(predicate);

  if (!asset) {
    throw new Error(`Could not find a matching release asset for ${owner}/${repo}`);
  }

  return asset.browser_download_url;
}

async function fetchJson(url) {
  const response = await fetch(url, {
    headers: {
      Accept: "application/vnd.github+json",
      "User-Agent": "borderless-toggle-build",
    },
  });

  if (!response.ok) {
    throw new Error(`Request failed ${response.status}: ${url}`);
  }

  return response.json();
}

async function downloadFile(url, targetPath) {
  const response = await fetch(url, {
    headers: {
      "User-Agent": "borderless-toggle-build",
    },
  });

  if (!response.ok) {
    throw new Error(`Download failed ${response.status}: ${url}`);
  }

  const tempPath = `${targetPath}.tmp`;
  const data = Buffer.from(await response.arrayBuffer());
  fs.writeFileSync(tempPath, data);

  fs.renameSync(tempPath, targetPath);
}

function extractZip(archivePath, extractDir) {
  fs.rmSync(extractDir, { force: true, recursive: true });
  fs.mkdirSync(extractDir, { recursive: true });

  execFileSync(
    "powershell.exe",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-Command",
      `Expand-Archive -LiteralPath ${quotePowerShell(archivePath)} -DestinationPath ${quotePowerShell(
        extractDir,
      )} -Force`,
    ],
    { stdio: "inherit" },
  );
}

function findFile(root, predicate) {
  const entries = fs.readdirSync(root, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(root, entry.name);

    if (entry.isDirectory()) {
      const nested = findFile(fullPath, predicate);
      if (nested) {
        return nested;
      }
    } else if (predicate(fullPath)) {
      return fullPath;
    }
  }

  return null;
}

function quotePowerShell(value) {
  return `'${value.replaceAll("'", "''")}'`;
}
