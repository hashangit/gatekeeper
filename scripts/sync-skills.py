#!/usr/bin/env python3
"""Bundle standalone skills from the router's canonical workflow files."""

import argparse
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "skills" / "gatekeeper"
SHARED = ("steps", "reviewers", "resources", "LICENSE")
RELEASE = ("config.sh", "FIRST_INSTALL.md", "PUBLISHING.md", "scripts")
DESCRIPTIONS = {
    "review": "Run the full adversarial Gatekeeper review after implementation or for a work order, branch, diff, or PR. Includes deterministic checks, task truth, fresh reviewers, findings verification, verdict, receipt, and bounded repairs. Ends before any commit or release operation.",
    "release": "Run Gatekeeper release verification and, only with explicit user consent for the actions, release operations. Use only when the user explicitly requests Release or confirms the model's proposal. A passing gate never authorizes committing, version bumps, tags, pushes, or publishing.",
}


def files_under(path):
    if path.is_symlink():
        raise ValueError(f"refusing symlink in skill source: {path}")
    if path.is_file():
        yield path
    else:
        for child in sorted(path.rglob("*")):
            if child.is_symlink():
                raise ValueError(f"refusing symlink in skill source: {child}")
            if child.is_file():
                yield child


def expected_files(mode):
    body = (SOURCE / "references" / f"{mode}.md").read_text()
    # Reference files use paths relative to references/; entrypoints sit at root.
    body = body.replace("](../", "](").replace("](setup.md)", "](references/setup.md)")
    entry = f"---\nname: gatekeeper-{mode}\ndescription: {DESCRIPTIONS[mode]}\nlicense: MIT\n---\n\n{body}"
    expected = {Path("SKILL.md"): entry.encode()}
    for name in SHARED + (RELEASE if mode == "release" else ()):
        for path in files_under(SOURCE / name):
            expected[path.relative_to(SOURCE)] = path.read_bytes()
    expected[Path("references/setup.md")] = (SOURCE / "references/setup.md").read_bytes()
    if mode == "review":
        config = (SOURCE / "config.sh").read_text().split("# --- package & gates")[0]
        config += "# --- gates -------------------------------------------------------------\n"
        for line in (SOURCE / "config.sh").read_text().splitlines():
            if line.startswith("GATE_"):
                config += line + "\n"
        expected[Path("config.sh")] = config.encode()
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail on bundle drift without writing")
    args = parser.parse_args()
    errors = []
    for mode in DESCRIPTIONS:
        target = ROOT / "skills" / f"gatekeeper-{mode}"
        expected = expected_files(mode)
        actual = {p.relative_to(target): p.read_bytes() for p in files_under(target)} if target.exists() else {}
        if args.check:
            for path in sorted(expected.keys() | actual.keys()):
                if expected.get(path) != actual.get(path):
                    errors.append(f"{target.relative_to(ROOT) / path}: missing, stale, or unexpected")
        else:
            # These directories are generated bundles, never canonical sources.
            if target.exists():
                shutil.rmtree(target)
            for path, content in expected.items():
                output = target / path
                output.parent.mkdir(parents=True, exist_ok=True)
                output.write_bytes(content)
            for script in (target / "scripts").glob("*"):
                script.chmod(script.stat().st_mode | 0o111)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        print("Run python3 scripts/sync-skills.py", file=sys.stderr)
        return 1
    print("Standalone skill bundles are current." if args.check else "Standalone skill bundles generated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
