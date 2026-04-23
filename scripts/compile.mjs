import fs from "fs";
import path from "path";
import { execFileSync } from "child_process";
import { getPackageVersion } from "./utils.mjs";

const buildDir = path.resolve("build");
const ahk2exe = path.resolve(".tools", "Ahk2Exe.exe");
const autoHotkey = path.resolve(".tools", "AutoHotkey64.exe");
const upx = path.resolve(".tools", "Upx.exe");

const appAhk = path.resolve("BorderlessToggle.ahk");
const generatedAhk = path.join(buildDir, "BorderlessToggle.generated.ahk");
const appExe = path.join(buildDir, "BorderlessToggle.exe");

if (!fs.existsSync(ahk2exe)) {
  throw new Error("Missing .tools/Ahk2Exe.exe. Run 'npm run setup' first.");
}

if (!fs.existsSync(autoHotkey)) {
  throw new Error("Missing .tools/AutoHotkey64.exe. Run 'npm run setup' first.");
}

if (!fs.existsSync(upx)) {
  throw new Error("Missing .tools/Upx.exe. Run 'npm run setup' first.");
}

if (!fs.existsSync(appAhk)) {
  throw new Error(`Missing source file: ${appAhk}`);
}

fs.mkdirSync(buildDir, { recursive: true });

const version = getPackageVersion();
const icons = {
  main: path.resolve("icons", "BorderlessToggle-App.ico"),
  activeLight: path.resolve("icons", "BorderlessToggle-Active-Light.ico"),
  inactiveLight: path.resolve("icons", "BorderlessToggle-Inactive-Light.ico"),
  activeDark: path.resolve("icons", "BorderlessToggle-Active-Dark.ico"),
  inactiveDark: path.resolve("icons", "BorderlessToggle-Inactive-Dark.ico"),
};

for (const icon of Object.values(icons)) {
  if (!fs.existsSync(icon)) {
    throw new Error(`Missing icon: ${icon}`);
  }
}

const source = fs
  .readFileSync(appAhk, "utf-8")
  .replaceAll("__APP_VERSION__", version)
  .replace(/^;@Ahk2Exe-SetMainIcon .+$/m, `;@Ahk2Exe-SetMainIcon ${icons.main}`)
  .replace(
    /^;@Ahk2Exe-AddResource .+BorderlessToggle-Active-Light\.ico, 201$/m,
    `;@Ahk2Exe-AddResource ${icons.activeLight}, 201`,
  )
  .replace(
    /^;@Ahk2Exe-AddResource .+BorderlessToggle-Inactive-Light\.ico, 202$/m,
    `;@Ahk2Exe-AddResource ${icons.inactiveLight}, 202`,
  )
  .replace(
    /^;@Ahk2Exe-AddResource .+BorderlessToggle-Suspended-Light\.ico, 203$/m,
    `;@Ahk2Exe-AddResource ${icons.suspendedLight}, 203`,
  )
  .replace(
    /^;@Ahk2Exe-AddResource .+BorderlessToggle-Active-Dark\.ico, 211$/m,
    `;@Ahk2Exe-AddResource ${icons.activeDark}, 211`,
  )
  .replace(
    /^;@Ahk2Exe-AddResource .+BorderlessToggle-Inactive-Dark\.ico, 212$/m,
    `;@Ahk2Exe-AddResource ${icons.inactiveDark}, 212`,
  )
  .replace(
    /^;@Ahk2Exe-AddResource .+BorderlessToggle-Suspended-Dark\.ico, 213$/m,
    `;@Ahk2Exe-AddResource ${icons.suspendedDark}, 213`,
  );

fs.writeFileSync(generatedAhk, source);

execFileSync(
  ahk2exe,
  ["/in", generatedAhk, "/out", appExe, "/base", autoHotkey, "/compress", "2"],
  { stdio: "inherit" },
);
