#!/usr/bin/env python3
"""Check bundles as isolated installations, including config mirrors and links."""

from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
NAMES = ("gatekeeper", "gatekeeper-review", "gatekeeper-release")


def check_install(skill):
    errors = []
    for path in skill.rglob("*.md"):
        # Untouched third-party source copies are not workflow entrypoints.
        if "resources" in path.relative_to(skill).parts:
            continue
        for link in re.findall(r"\]\(([^)\s]+)\)", path.read_text()):
            if "://" in link or link.startswith("#"):
                continue
            target = (path.parent / link.split("#")[0]).resolve()
            if not target.is_relative_to(skill.resolve()) or not target.exists():
                errors.append(f"{path.relative_to(skill)}: missing or escaping link {link}")
    config = dict(re.findall(r'^([A-Z_]+)="(.*)"$', (skill / "config.sh").read_text(), re.M))
    workflows = [skill / "SKILL.md"]
    if skill.name == "gatekeeper":
        workflows = [skill / "references/review.md", skill / "references/release.md"]
    for workflow in workflows:
        mirrored = dict(re.findall(r"^- `([A-Z_]+)` .* = `(.*?)`$", workflow.read_text(), re.M))
        applicable = config if "release" in workflow.name or skill.name == "gatekeeper-release" else {
            key: value for key, value in config.items()
            if key.endswith("_PATH") or key.startswith("GATE_")
        }
        if mirrored != applicable:
            errors.append(f"{workflow.relative_to(skill)}: config.sh and Configuration disagree")
    if skill.name == "gatekeeper-review" and (skill / "scripts/publish.sh").exists():
        errors.append("Review bundles must not contain a publisher")
    return errors


def main():
    result = subprocess.run([sys.executable, str(ROOT / "scripts/sync-skills.py"), "--check"])
    if result.returncode:
        return result.returncode
    errors = []
    with tempfile.TemporaryDirectory(prefix="gatekeeper-check-") as temporary:
        for name in NAMES:
            installed = Path(temporary) / name
            shutil.copytree(ROOT / "skills" / name, installed)
            errors.extend(f"{name}: {error}" for error in check_install(installed))
        # Confirm missing required files cannot pass the containment check.
        damaged = Path(temporary) / "gatekeeper-review"
        (damaged / "steps/phase-1-seal.md").unlink()
        if not check_install(damaged):
            errors.append("Missing phase file was not detected")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("All three isolated installations have complete links and matching configuration.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
