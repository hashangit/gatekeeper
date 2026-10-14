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
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { join } from "node:path";

const REPO_ROOT = execFileSync("git", ["rev-parse", "--show-toplevel"], { cwd: process.cwd(), encoding: "utf8" }).trim();

const VERSION = process.argv[2];
const STDOUT_ONLY = process.argv.includes("--stdout");

if (!VERSION || !/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/.test(VERSION)) {
  console.error("Usage: node generate-release-notes.mjs <version> [--stdout]");
  console.error("  version must be semver, e.g. 0.3.1");
  process.exit(1);
}

function runGit(args) {
  return execFileSync("git", args, { cwd: REPO_ROOT, encoding: "utf8" }).trim();
}

// Resolve the previous tag to an object ID before using it as a revision.
// Tag names are repository data and may look like Git options.
let previousRevision;
try {
  previousRevision = runGit(["describe", "--tags", "--abbrev=0", "HEAD~1"]);
} catch {
  try {
    previousRevision = runGit(["describe", "--tags", "--abbrev=0"]);
  } catch {
    previousRevision = runGit(["rev-list", "--max-parents=0", "HEAD"]);
  }
}

const previousCommit = runGit([
  "rev-parse",
  "--verify",
  "--end-of-options",
  `${previousRevision}^{commit}`,
]);
const log = runGit(["log", "--no-merges", "--pretty=format:%s", `${previousCommit}..HEAD`])
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
  lines.push(`- No categorized changes since ${previousRevision}. Edit these notes before publishing.`, "");
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
  console.error(`Wrote ${outPath} (from ${log.length} commits since ${previousRevision})`);
}
