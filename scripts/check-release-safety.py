#!/usr/bin/env python3
"""Exercise release-path defenses against hostile tags and source symlinks."""

from importlib.util import module_from_spec, spec_from_file_location
import json
import os
import pty
from pathlib import Path
import select
import shutil
import shlex
import stat
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def run(*args, cwd, check=True):
    return subprocess.run(args, cwd=cwd, check=check, text=True, capture_output=True)


def sealed_release_receipt(seal, verdict="PASS"):
    return (
        f"Mode: RELEASE\n"
        f"Branch: `main` | Seal: `{seal}` | Gates: suite 1/1, build 1/1\n"
        f"Verdict: {verdict}\n"
    )


def check_sync_rejects_symlink():
    spec = spec_from_file_location("sync_skills", ROOT / "scripts" / "sync-skills.py")
    module = module_from_spec(spec)
    spec.loader.exec_module(module)

    original_root = module.ROOT
    try:
        with tempfile.TemporaryDirectory(prefix="gatekeeper-symlink-test-") as temporary:
            test_root = Path(temporary)
            folder = test_root / "source"
            folder.mkdir()
            outside = test_root / "outside.env"
            outside.write_text("test-secret", encoding="utf-8")
            (folder / "leak.md").symlink_to(outside)
            module.ROOT = test_root
            try:
                list(module.files_under(folder))
            except ValueError as error:
                if "refusing symlink" not in str(error):
                    raise
            else:
                raise AssertionError("skill source scanner accepted an outside-target symlink")
    finally:
        module.ROOT = original_root

    original_root, original_source = module.ROOT, module.SOURCE
    try:
        with tempfile.TemporaryDirectory(prefix="gatekeeper-reference-symlink-") as temporary:
            root = Path(temporary) / "repo"
            source = root / "skills" / "gatekeeper"
            references = source / "references"
            references.mkdir(parents=True)
            outside = Path(temporary) / "outside-review.md"
            outside.write_text("outside sentinel", encoding="utf-8")
            (references / "review.md").symlink_to(outside)
            module.ROOT, module.SOURCE = root, source
            try:
                module.expected_files("review")
            except ValueError as error:
                if "refusing symlink" not in str(error):
                    raise
            else:
                raise AssertionError("bundle generator followed a symlinked canonical reference")
    finally:
        module.ROOT, module.SOURCE = original_root, original_source


def check_notes_generator_does_not_execute_tag():
    node = shutil.which("node")
    git = shutil.which("git")
    if not node or not git:
        raise RuntimeError("node and git are required for release safety checks")

    with tempfile.TemporaryDirectory(prefix="gatekeeper-tag-test-") as temporary:
        temporary_root = Path(temporary)
        generator = ROOT / "skills" / "gatekeeper" / "scripts" / "generate-release-notes.mjs"
        spill_target = temporary_root / "git-log-output"
        hostile_tag_cases = [
            ("--output=spill", spill_target),
            (f"v1.0.0;touch${{IFS}}{temporary_root / 'tag-command-ran'};#", None),
        ]
        for index, (hostile_tag, spill) in enumerate(hostile_tag_cases):
            repo = temporary_root / f"repo-{index}"
            repo.mkdir()
            scripts = temporary_root / f"installed-skill-{index}" / "scripts"
            scripts.mkdir(parents=True)
            shutil.copy2(generator, scripts / generator.name)
            run(git, "init", "-q", cwd=repo)
            run(git, "config", "user.name", "Gatekeeper test", cwd=repo)
            run(git, "config", "user.email", "gatekeeper-test@example.invalid", cwd=repo)
            (repo / "history.txt").write_text("first\n", encoding="utf-8")
            run(git, "add", "history.txt", cwd=repo)
            run(git, "commit", "-qm", "feat: first release", cwd=repo)
            if hostile_tag.startswith("--"):
                run(git, "update-ref", f"refs/tags/{hostile_tag}", "HEAD", cwd=repo)
            else:
                run(git, "tag", hostile_tag, cwd=repo)
            (repo / "history.txt").write_text("second\n", encoding="utf-8")
            run(git, "commit", "-qam", "feat: next change", cwd=repo)
            if spill is not None:
                (repo / "spill..HEAD").symlink_to(spill)

            result = run(
                node, str(scripts / generator.name), "2.0.0", cwd=repo, check=False
            )
            if result.returncode != 0:
                raise AssertionError(f"notes generator failed on a valid hostile tag: {result.stderr}")
            marker = temporary_root / "tag-command-ran"
            if spill is not None and spill.exists():
                raise AssertionError("a Git tag redirected git log output outside the repository")
            if marker.exists():
                raise AssertionError("a Git tag executed a shell command in the release-notes generator")


def check_publisher_receipt_and_plugin_manifest():
    git = shutil.which("git")
    jq = shutil.which("jq")
    if not git or not jq:
        raise RuntimeError("git and jq are required for publisher safety checks")

    with tempfile.TemporaryDirectory(prefix="gatekeeper-publisher-test-") as temporary:
        temporary_root = Path(temporary)
        repo = temporary_root / "repo"
        origin = temporary_root / "origin.git"
        repo.mkdir()
        run(git, "init", "--bare", "-q", "--initial-branch=main", str(origin), cwd=temporary_root)
        run(git, "init", "-q", str(repo), cwd=temporary_root)
        run(git, "-C", str(repo), "checkout", "-qb", "main", cwd=temporary_root)
        run(git, "-C", str(repo), "config", "user.name", "Gatekeeper test", cwd=temporary_root)
        run(git, "-C", str(repo), "config", "user.email", "gatekeeper-test@example.invalid", cwd=temporary_root)

        manifest_dir = repo / ".claude-plugin"
        manifest_dir.mkdir()
        manifest = manifest_dir / "plugin.json"
        manifest.write_text(json.dumps({"name": "gatekeeper", "version": "1.0.0"}), encoding="utf-8")
        scripts = repo / "skills" / "gatekeeper" / "scripts"
        scripts.mkdir(parents=True)
        publisher = ROOT / "skills" / "gatekeeper" / "scripts" / "publish.sh"
        shutil.copy2(publisher, scripts / publisher.name)
        (scripts.parent / "config.sh").write_text(
            'REVIEW_FOLDER_PATH="Reviews"\n'
            'IMPLEMENTATION_SPEC_PATH="specs"\n'
            'WORK_ORDER_PATH="work-orders/<work-order>/tasks.md"\n'
            'PACKAGE_NAME="gatekeeper"\nCORE_PACKAGE_NAME=""\n'
            'GATE_TEST_CMD="false"\nGATE_BUILD_CMD="false"\n'
            'GATE_PROBES_CMD=""\nGATE_EXAMPLES_CMD=""\n'
            'RELEASE_CI_WORKFLOW="release.yml"\nRELEASE_NOTES_CMD=""\nHOMEBREW_TAP_REPO=""\n',
            encoding="utf-8",
        )
        run(git, "-C", str(repo), "add", ".claude-plugin", "skills", cwd=temporary_root)
        run(git, "-C", str(repo), "commit", "-qm", "candidate", cwd=temporary_root)
        run(git, "-C", str(repo), "tag", "v1.0.0", cwd=temporary_root)
        run(git, "-C", str(repo), "remote", "add", "origin", str(origin), cwd=temporary_root)
        run(git, "-C", str(repo), "push", "-qu", "origin", "main", cwd=temporary_root)
        run(git, "-C", str(repo), "push", "-q", "origin", "v1.0.0", cwd=temporary_root)

        reviews = repo / "Reviews"
        reviews.mkdir()
        receipt = reviews / "test-gatekeeper-RELEASE.md"
        seal = run(git, "-C", str(repo), "rev-parse", "HEAD", cwd=temporary_root).stdout.strip()
        valid_receipt = sealed_release_receipt(seal)
        receipt.write_text(
            valid_receipt,
            encoding="utf-8",
        )

        fake_bin = temporary_root / "bin"
        fake_bin.mkdir()
        fake_gh = fake_bin / "gh"
        fake_gh.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        fake_gh.chmod(fake_gh.stat().st_mode | stat.S_IXUSR)
        environment = os.environ.copy()
        environment["PATH"] = f"{fake_bin}{os.pathsep}{environment['PATH']}"

        accepted = subprocess.run(
            ["bash", str(scripts / publisher.name), "1.0.1", "--dry-run"],
            cwd=repo, env=environment, text=True, capture_output=True,
        )
        if accepted.returncode != 0 or "--dry-run" not in accepted.stdout:
            raise AssertionError(f"publisher rejected a sealed PASS receipt: {accepted.stdout}{accepted.stderr}")
        if json.loads(manifest.read_text(encoding="utf-8"))["version"] != "1.0.0":
            raise AssertionError("publisher dry-run changed the plugin manifest")

        receipt.write_text(
            f"Mode: RELEASE\nSeal: `{seal}`\nVerdict: PASS\n",
            encoding="utf-8",
        )
        minimal = subprocess.run(
            ["bash", str(scripts / publisher.name), "1.0.1", "--dry-run"],
            cwd=repo, env=environment, text=True, capture_output=True,
        )
        if minimal.returncode == 0:
            raise AssertionError("publisher accepted a receipt missing the structured seal header")

        receipt.write_text(sealed_release_receipt(seal, verdict="FAIL"), encoding="utf-8")
        rejected = subprocess.run(
            ["bash", str(scripts / publisher.name), "1.0.1", "--dry-run"],
            cwd=repo, env=environment, text=True, capture_output=True,
        )
        if rejected.returncode == 0 or "Run Gatekeeper Release first" not in rejected.stderr:
            raise AssertionError("publisher accepted a failing Release receipt")

        marker = temporary_root / "publisher-command-ran"
        manifest.write_text(
            json.dumps({"name": "gatekeeper", "version": f"1.BASH_VERSINFO[$(touch {marker})].0"}),
            encoding="utf-8",
        )
        run(git, "-C", str(repo), "add", ".claude-plugin/plugin.json", cwd=temporary_root)
        run(git, "-C", str(repo), "commit", "-qm", "test: malformed manifest version", cwd=temporary_root)
        run(git, "-C", str(repo), "push", "-q", "origin", "main", cwd=temporary_root)
        malformed = subprocess.run(
            ["bash", str(scripts / publisher.name), "patch", "--dry-run"],
            cwd=repo, env=environment, text=True, capture_output=True,
        )
        if malformed.returncode == 0 or marker.exists():
            raise AssertionError("publisher evaluated a malformed manifest version as shell arithmetic")

        long_patch = "9" * 24
        long_target = f"1.0.{'1' + ('0' * len(long_patch))}"
        manifest.write_text(
            json.dumps({"name": "gatekeeper", "version": f"1.0.{long_patch}"}),
            encoding="utf-8",
        )
        run(git, "-C", str(repo), "add", ".claude-plugin/plugin.json", cwd=temporary_root)
        run(git, "-C", str(repo), "commit", "-qm", "test: long semver component", cwd=temporary_root)
        run(git, "-C", str(repo), "push", "-q", "origin", "main", cwd=temporary_root)
        seal = run(git, "-C", str(repo), "rev-parse", "HEAD", cwd=temporary_root).stdout.strip()
        receipt.write_text(sealed_release_receipt(seal), encoding="utf-8")
        long_version = subprocess.run(
            ["bash", str(scripts / publisher.name), "patch", "--dry-run"],
            cwd=repo, env=environment, text=True, capture_output=True,
        )
        if long_version.returncode != 0 or long_target not in long_version.stdout:
            raise AssertionError(f"publisher failed to safely bump a long semver component: {long_version.stdout}{long_version.stderr}")


def check_publisher_runs_both_gates_and_stages_npm_lockfiles():
    git = shutil.which("git")
    jq = shutil.which("jq")
    node = shutil.which("node")
    if not git or not jq or not node:
        raise RuntimeError("git, jq, and node are required for publisher safety checks")

    with tempfile.TemporaryDirectory(prefix="gatekeeper-publish-flow-") as temporary:
        temporary_root = Path(temporary)
        repo = temporary_root / "repo"
        origin = temporary_root / "origin.git"
        repo.mkdir()
        run(git, "init", "--bare", "-q", "--initial-branch=main", str(origin), cwd=temporary_root)
        run(git, "init", "-q", str(repo), cwd=temporary_root)
        run(git, "-C", str(repo), "checkout", "-qb", "main", cwd=temporary_root)
        run(git, "-C", str(repo), "config", "user.name", "Gatekeeper test", cwd=temporary_root)
        run(git, "-C", str(repo), "config", "user.email", "gatekeeper-test@example.invalid", cwd=temporary_root)

        manifest = repo / "package.json"
        manifest.write_text(json.dumps({"name": "gatekeeper", "version": "1.0.0"}), encoding="utf-8")
        lockfile = repo / "package-lock.json"
        lockfile.write_text(
            json.dumps({
                "name": "gatekeeper",
                "version": "1.0.0",
                "lockfileVersion": 3,
                "packages": {"": {"name": "gatekeeper", "version": "1.0.0"}},
            }),
            encoding="utf-8",
        )
        scripts = repo / "skills" / "gatekeeper" / "scripts"
        scripts.mkdir(parents=True)
        source_scripts = ROOT / "skills" / "gatekeeper" / "scripts"
        for name in ("publish.sh", "generate-release-notes.mjs"):
            shutil.copy2(source_scripts / name, scripts / name)

        gate_log = temporary_root / "gate-order.log"
        config = scripts.parent / "config.sh"
        config.write_text(
            'REVIEW_FOLDER_PATH="Reviews"\n'
            'IMPLEMENTATION_SPEC_PATH="specs"\n'
            'WORK_ORDER_PATH="work-orders/<work-order>/tasks.md"\n'
            'PACKAGE_NAME="gatekeeper"\nCORE_PACKAGE_NAME=""\n'
            f'GATE_TEST_CMD="echo test >> {shlex.quote(str(gate_log))}"\n'
            f'GATE_BUILD_CMD="echo build >> {shlex.quote(str(gate_log))}"\n'
            'GATE_PROBES_CMD=""\nGATE_EXAMPLES_CMD=""\n'
            'RELEASE_CI_WORKFLOW="release.yml"\n'
            'RELEASE_NOTES_CMD=\'test "$1" = "1.0.1" && printf "notes for %s\\n" "$1" > "RELEASE_NOTES-v$1.md"\'\n'
            'HOMEBREW_TAP_REPO=""\n',
            encoding="utf-8",
        )
        run(git, "-C", str(repo), "add", "package.json", "package-lock.json", "skills", cwd=temporary_root)
        run(git, "-C", str(repo), "commit", "-qm", "feat: candidate", cwd=temporary_root)
        run(git, "-C", str(repo), "tag", "v1.0.0", cwd=temporary_root)
        run(git, "-C", str(repo), "remote", "add", "origin", str(origin), cwd=temporary_root)
        run(git, "-C", str(repo), "push", "-qu", "origin", "main", cwd=temporary_root)
        run(git, "-C", str(repo), "push", "-q", "origin", "v1.0.0", cwd=temporary_root)

        reviews = repo / "Reviews"
        reviews.mkdir()
        seal = run(git, "-C", str(repo), "rev-parse", "HEAD", cwd=temporary_root).stdout.strip()
        (reviews / "test-gatekeeper-RELEASE.md").write_text(
            sealed_release_receipt(seal),
            encoding="utf-8",
        )

        fake_bin = temporary_root / "bin"
        fake_bin.mkdir()
        gh_log = temporary_root / "gh.log"
        fake_gh = fake_bin / "gh"
        fake_gh.write_text(
            "#!/bin/sh\n"
            'case "$1 $2" in\n'
            '  "auth status"|"release view") exit 0 ;;\n'
            '  "run list")\n'
            '    for arg in "$@"; do case "$arg" in --commit=*) sha=${arg#--commit=} ;; esac; done\n'
            '    printf \'[{"databaseId":123,"headSha":"%s"}]\\n\' "$sha"\n'
            '    ;;\n'
            '  "run watch") echo watched >> ' + shlex.quote(str(gh_log)) + '; exit 0 ;;\n'
            '  "repo view") echo https://github.com/test/gatekeeper ;;\n'
            '  *) exit 0 ;;\n'
            'esac\n',
            encoding="utf-8",
        )
        fake_gh.chmod(fake_gh.stat().st_mode | stat.S_IXUSR)
        fake_npm = fake_bin / "npm"
        fake_npm.write_text(
            "#!/bin/sh\n"
            'if [ "$1" = "view" ]; then\n'
            '  if [ "$2" = "gatekeeper" ]; then echo 1.0.0; exit 0; fi\n'
            '  exit 1\n'
            'fi\n'
            'if [ "$1" = "version" ]; then\n'
            '  python3 - "$2" <<\'PY\'\n'
            'import json, pathlib, sys\n'
            'version = sys.argv[1]\n'
            'for name in ("package.json", "package-lock.json"):\n'
            '    path = pathlib.Path(name)\n'
            '    data = json.loads(path.read_text())\n'
            '    data["version"] = version\n'
            '    if name == "package-lock.json": data["packages"][""]["version"] = version\n'
            '    path.write_text(json.dumps(data))\n'
            'PY\n'
            '  exit $?\n'
            'fi\n'
            'exit 1\n',
            encoding="utf-8",
        )
        fake_npm.chmod(fake_npm.stat().st_mode | stat.S_IXUSR)
        environment = os.environ.copy()
        environment["PATH"] = f"{fake_bin}{os.pathsep}{environment['PATH']}"

        child_pid, master_fd = pty.fork()
        if child_pid == 0:
            os.chdir(repo)
            os.execvpe("bash", ["bash", str(scripts / "publish.sh"), "1.0.1"], environment)
        os.write(master_fd, b"y\nn\n")
        output = bytearray()
        deadline = time.monotonic() + 30
        status = None
        while time.monotonic() < deadline:
            if select.select([master_fd], [], [], 0.1)[0]:
                try:
                    chunk = os.read(master_fd, 4096)
                except OSError:
                    chunk = b""
                output.extend(chunk)
            waited_pid, child_status = os.waitpid(child_pid, os.WNOHANG)
            if waited_pid:
                status = child_status
                break
        if status is None:
            os.kill(child_pid, 9)
            _, status = os.waitpid(child_pid, 0)
            os.close(master_fd)
            raise AssertionError("publisher integration did not finish in 30 seconds")
        while select.select([master_fd], [], [], 0)[0]:
            try:
                chunk = os.read(master_fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            output.extend(chunk)
        os.close(master_fd)
        text = output.decode(errors="replace")
        if os.waitstatus_to_exitcode(status) != 0:
            raise AssertionError(f"publisher flow failed: {text}")
        if gate_log.read_text(encoding="utf-8").splitlines() != ["test", "build"]:
            raise AssertionError("publisher did not run test then build gates")
        if json.loads(manifest.read_text(encoding="utf-8"))["version"] != "1.0.1":
            raise AssertionError("publisher did not bump the npm manifest")
        lock = json.loads(lockfile.read_text(encoding="utf-8"))
        if lock["version"] != "1.0.1" or lock["packages"][""]["version"] != "1.0.1":
            raise AssertionError("publisher did not bump package-lock.json")
        notes = repo / "RELEASE_NOTES-v1.0.1.md"
        if notes.read_text(encoding="utf-8").strip() != "notes for 1.0.1":
            raise AssertionError("custom notes generator did not receive the target version as $1")
        committed_files = run(
            git, "-C", str(repo), "show", "--format=", "--name-only", "HEAD", cwd=temporary_root
        ).stdout.splitlines()
        if "Reviews/test-gatekeeper-RELEASE.md" not in committed_files:
            raise AssertionError("release commit did not include its PASS receipt")
        if "package-lock.json" not in committed_files:
            raise AssertionError("release commit did not include the updated package lockfile")
        if run(git, "-C", str(repo), "status", "--porcelain", cwd=temporary_root).stdout.strip():
            raise AssertionError("publisher left changes after the release commit")
        if not gh_log.is_file() or "watched" not in gh_log.read_text(encoding="utf-8"):
            raise AssertionError("publisher did not watch the matching Actions run")
        if run(git, "-C", str(repo), "cat-file", "-t", "refs/tags/v1.0.1", cwd=temporary_root).stdout.strip() != "tag":
            raise AssertionError("publisher did not create an annotated release tag")


def main():
    check_sync_rejects_symlink()
    check_notes_generator_does_not_execute_tag()
    check_publisher_receipt_and_plugin_manifest()
    check_publisher_runs_both_gates_and_stages_npm_lockfiles()
    print("Release safety checks passed.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Release safety check failed: {error}", file=sys.stderr)
        raise
