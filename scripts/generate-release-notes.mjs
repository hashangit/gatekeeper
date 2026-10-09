#!/usr/bin/env node
/**
 * Generate release notes from git history — zero dependencies, no network, no LLM.
 *
 * Reads conventional commits since the previous tag and formats them per
 * Keep a Changelog. feat→Added, fix→Fixed, perf/refactor→Changed,
 * revert→Removed, security→Security. chore/test/ci/docs are skipped.
 *
 * Usage:
 *   node generate-release-notes.mjs <version> [--stdout]
 *
 * Set RELEASE_NOTES_CMD in config.sh to override this with your own generator.
 */
import { execSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = execSync("git rev-parse --show-toplevel", { cwd: __dirname, encoding: "utf8" }).trim();

const VERSION = process.argv[2];
const STDOUT_ONLY = process.argv.includes("--stdout");

if (!VERSION || !/^\d+\.\d+\.\d+$/.test(VERSION)) {
  console.error("Usage: node generate-release-notes.mjs <version> [--stdout]");
  console.error("  version must be semver, e.g. 0.3.1");
  process.exit(1);
}

function run(cmd) {
  return execSync(cmd, { cwd: REPO_ROOT, encoding: "utf8" }).trim();
}

// Previous tag; fall back to the first commit on a fresh repo.
let prevTag;
try {
  prevTag = run("git describe --tags --abbrev=0 HEAD~1 2>/dev/null || git describe --tags --abbrev=0 2>/dev/null");
} catch {
  prevTag = run("git rev-list --max-parents=0 HEAD");
}

const log = run(`git log ${prevTag}..HEAD --no-merges --pretty=format:"%s"`)
  .split("\n")
  .map((s) => s.trim())
  .filter(Boolean);

// Conventional-commit type -> Keep a Changelog section. Absent = skipped.
const SECTION = {
  feat: "Added",
  fix: "Fixed",
  perf: "Changed",
  refactor: "Changed",
  revert: "Removed",
  security: "Security",
};

const sections = new Map();
for (const subject of log) {
  const m = subject.match(/^(\w+)(?:\([^)]*\))?!?:\s+(.+)$/);
  if (!m) continue; // not conventional — let the human add it
  const section = SECTION[m[1].toLowerCase()];
  if (!section) continue;
  if (!sections.has(section)) sections.set(section, new Set());
  sections.get(section).add(m[2].replace(/ \(#\d+\)$/i, ""));
}

const today = new Date().toISOString().slice(0, 10);
const lines = [`## [${VERSION}] - ${today}`, ""];

if (sections.size === 0) {
  lines.push(`- No categorized changes since ${prevTag}. Edit these notes before publishing.`, "");
} else {
  for (const [section, items] of sections) {
    lines.push(`### ${section}`);
    for (const item of items) lines.push(`- ${item.charAt(0).toUpperCase() + item.slice(1)}`);
    lines.push("");
  }
}

const output = lines.join("\n").trimEnd() + "\n";

if (STDOUT_ONLY) {
  process.stdout.write(output);
} else {
  const outPath = join(REPO_ROOT, `RELEASE_NOTES-v${VERSION}.md`);
  writeFileSync(outPath, output);
  console.error(`Wrote ${outPath} (from ${log.length} commits since ${prevTag})`);
}
