import fs from "fs";
import path from "path";

const buildDir = path.resolve("build");
const cacheDir = path.resolve(".cache");
const distDir = path.resolve("dist");
const iconsDir = path.resolve("icons");

function remove(target) {
  try {
    fs.rmSync(target, { force: true, recursive: true });
  } catch {}
}

remove(buildDir);
remove(cacheDir);
remove(distDir);
remove(iconsDir);
