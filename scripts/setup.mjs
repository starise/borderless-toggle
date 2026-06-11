import fs from "fs";
import path from "path";
import crypto from "crypto";
import { execFileSync } from "child_process";

const toolsDir = path.resolve(".tools");
const cacheDir = path.resolve(".cache", "tools");
const force = process.argv.includes("--force");

const tools = [
  {
    name: "AutoHotkey v2 2.0.26",
    outputName: "AutoHotkey64.exe",
    source: "https://www.autohotkey.com/download/2.0/AutoHotkey_2.0.26.zip",
    sha256: "43522aa3122a57784ac5db30abf85c2244475c36acd7796e2c993355f9e926ae",
    match: (file) => path.basename(file).toLowerCase() === "autohotkey64.exe",
  },
  {
    name: "Ahk2Exe 1.1.37.02a2",
    outputName: "Ahk2Exe.exe",
    source:
      "https://github.com/AutoHotkey/Ahk2Exe/releases/download/Ahk2Exe1.1.37.02a2/Ahk2Exe1.1.37.02a2.zip",
    sha256: "c29b8c3a5124850d79fc9e66e2ca79677c377d7f31631ad3022ba159c5d9e3be",
    match: (file) => path.basename(file).toLowerCase() === "ahk2exe.exe",
  },
  {
    name: "UPX 5.2.0",
    outputName: "Upx.exe",
    source: "https://github.com/upx/upx/releases/download/v5.2.0/upx-5.2.0-win64.zip",
    sha256: "b471ebf1b7f20f4a89150264ed9a008a2a5bfd247f3c6d1184a75bb59ca08f5d",
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

  const archivePath = path.join(cacheDir, `${tool.outputName}.zip`);
  const extractDir = path.join(cacheDir, `${path.basename(tool.outputName, ".exe")}-extract`);

  await downloadFile(tool.source, archivePath);
  verifySha256(archivePath, tool.sha256);
  extractZip(archivePath, extractDir);

  const sourceExe = findFile(extractDir, tool.match);
  if (!sourceExe) {
    throw new Error(`Could not find ${tool.outputName} inside ${archivePath}`);
  }

  fs.copyFileSync(sourceExe, outputPath);
  console.log(`OK  ${tool.outputName}`);
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

function verifySha256(filePath, expectedHash) {
  const hash = crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");

  if (hash !== expectedHash) {
    throw new Error(`Checksum mismatch for ${filePath}: expected ${expectedHash}, got ${hash}`);
  }
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
