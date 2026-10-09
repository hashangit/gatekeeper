# Resources

Verbatim copies of the skills the reviewer files in `../reviewers/` were adapted from.
This skill is self-contained — it never calls those skills externally; the copies exist
so the review method ships with the gate. The originals live in their authors' repos
and are untouched.

| Copy | Adapted into | Original author | How it's used |
|---|---|---|---|
| `code-review/` | `reviewers/code-reviewer.md` | CodeRabbit (tooling: CodeRabbit) | CodeRabbit CLI run over the sealed diff range — the Code Reviewer's engine |
| `scrutinize/` | `reviewers/scrutinizer.md` | thananon — [9arm-skills](https://github.com/thananon/9arm-skills), `skills/engineering/scrutinize` | Outsider stance: intent first, then trace and verify — retargeted from code paths to the documented user path |
| `product-review/` | `reviewers/repo-auditor.md` | Hashan Wickramasinghe | The 360° cross-layer pass (duplicates, drift, seams, orphans) — the Repo Auditor's read-across method; `references/` lenses included |
| `repo-review-ultra-deep/` | `reviewers/architect.md` | Jacob Rothfield — "Repo Review Agent — Prompts" (Ultra-Deep v5.4.2), [Medium](https://medium.com/@jacobrothfield/repo-review-agent-prompts-d6205bcfc034) | Evidence discipline `[E#]`, two-method P0 bar, contradiction scan — the Architect's toolkit |
| `ponytail-review/` | `reviewers/ponytail-reviewer.md` | Dietrich Gebert — [ponytail](https://github.com/DietrichGebert/ponytail), MIT | Over-engineering hunt: what to cut in the sealed diff — the Ponytail Reviewer's whole job |
| `red-team/` | `reviewers/red-team.md` | Hashan Wickramasinghe | The burglar and the examiner — exploitable behavior and implementation flaws, proven with demonstrations and concrete scenarios |
| `security-review/` | `reviewers/security-reviewer.md` | Hashan Wickramasinghe | The white-hat sweep — known vulnerability classes, OWASP/CWE patterns, dependency CVEs, attacker-shaped inputs |
