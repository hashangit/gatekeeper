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
    path = require_safe_source(path)
    if path.is_file():
        yield path
    else:
        for child in sorted(path.rglob("*")):
            child = require_safe_source(child)
            if child.is_file():
                yield child


def reject_symlink_components(path):
    path = Path(path)
    if not path.is_absolute():
        path = ROOT / path
    try:
        relative = path.relative_to(ROOT)
    except ValueError as error:
        raise ValueError(f"refusing skill source outside repository: {path}") from error

    current = ROOT
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f"refusing symlink path component: {current}")
    return path


def require_safe_source(path):
    """Reject symlinks in any path component before reading canonical sources."""
    path = reject_symlink_components(path)
    if not path.exists():
        raise ValueError(f"missing skill source: {path}")
    return path


def read_source_bytes(path):
    return require_safe_source(path).read_bytes()


def read_source_text(path):
    return require_safe_source(path).read_text()


def expected_files(mode):
    body = read_source_text(SOURCE / "references" / f"{mode}.md")
    # Reference files use paths relative to references/; entrypoints sit at root.
    body = body.replace("](../", "](").replace("](setup.md)", "](references/setup.md)")
    entry = f"---\nname: gatekeeper-{mode}\ndescription: {DESCRIPTIONS[mode]}\nlicense: MIT\n---\n\n{body}"
    expected = {Path("SKILL.md"): entry.encode()}
    for name in SHARED + (RELEASE if mode == "release" else ()):
        for path in files_under(SOURCE / name):
            expected[path.relative_to(SOURCE)] = read_source_bytes(path)
    expected[Path("references/setup.md")] = read_source_bytes(SOURCE / "references/setup.md")
    if mode == "release":
        expected[Path("assets/release.yml")] = read_source_bytes(ROOT / ".github" / "workflows" / "release.yml")
    if mode == "review":
        config_text = read_source_text(SOURCE / "config.sh")
        config = config_text.split("# --- package & gates")[0]
        config += "# --- gates -------------------------------------------------------------\n"
        for line in config_text.splitlines():
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
        target = reject_symlink_components(target)
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
