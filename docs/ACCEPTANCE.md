# Acceptance checklist — MoonBit Sep 2026 hackathon

Each official acceptance requirement mapped to evidence in this repo.
Repo: <https://github.com/bob0627/agent-schema-lint> (public, branch `master`). Checked on 2026-09-30.

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | MoonBit is the main language | ✅ | All logic is MoonBit: [`lint.mbt`](../lint.mbt) (rules), [`diagnostic.mbt`](../diagnostic.mbt) (types, text/JSON output), [`cmd/main/main.mbt`](../cmd/main/main.mbt) (CLI), plus `*_test.mbt`. The only non-MoonBit code is the ~100-line POSIX sh generator [`scripts/gen_fixture_tests.sh`](../scripts/gen_fixture_tests.sh) and JSON fixtures. |
| 2 | Public repo with continuous, traceable commits | ✅ | `git log`: initial v0.1 on 2026-09-23, then small conventional commits (`feat:`/`test:`/`docs:`/`chore:`/`fix:`) on 2026-09-30, merged through PRs (no force pushes, no history rewrite). |
| 3 | Issues and PRs used for the work | ✅ | Scope issue [#1](https://github.com/bob0627/agent-schema-lint/issues/1). Work items, each Issue → branch → PR → merge: [#2](https://github.com/bob0627/agent-schema-lint/issues/2) → [PR #3](https://github.com/bob0627/agent-schema-lint/pull/3) fixture regression tests; [#4](https://github.com/bob0627/agent-schema-lint/issues/4) → [PR #5](https://github.com/bob0627/agent-schema-lint/pull/5) `--format json` + exit codes; [#6](https://github.com/bob0627/agent-schema-lint/issues/6) → [PR #7](https://github.com/bob0627/agent-schema-lint/pull/7) rule ASL009; [#12](https://github.com/bob0627/agent-schema-lint/issues/12) → [PR #13](https://github.com/bob0627/agent-schema-lint/pull/13) CLI output order fix; [#11](https://github.com/bob0627/agent-schema-lint/issues/11) → [PR #14](https://github.com/bob0627/agent-schema-lint/pull/14) docs. Future work (open, not implemented): [#8](https://github.com/bob0627/agent-schema-lint/issues/8), [#9](https://github.com/bob0627/agent-schema-lint/issues/9), [#10](https://github.com/bob0627/agent-schema-lint/issues/10). |
| 4 | Clear README | ✅ | [`README.md`](../README.md) (symlink to `README.mbt.md`): Why, Install/build, Quick demo (real captured output), Usage + exit codes, Library API, Rules table with a trigger per rule, Testing, Scope, Roadmap. |
| 5 | Runnable example | ✅ | `moon run cmd/main -- fixtures/ok/minimal.json` (exit 0), `moon run cmd/main -- fixtures/bad/required_unknown.json` (exit 1), `moon run cmd/main -- --format json fixtures/bad/required_unknown.json`. 13 fixtures under [`fixtures/`](../fixtures) (`ok` 4, `warn` 2, `bad` 7). |
| 6 | Necessary tests | ✅ | `moon test` → **32 passed, 0 failed**: rule unit tests ([`agent-schema-lint_test.mbt`](../agent-schema-lint_test.mbt)), JSON output tests ([`json_output_test.mbt`](../json_output_test.mbt)), and one generated test per fixture ([`fixtures_test.mbt`](../fixtures_test.mbt)) asserting the expected code from `fixtures/{bad,warn}/expected.txt`. `scripts/gen_fixture_tests.sh --check` guards against drift. |
| 7 | Open-source license | ✅ | [`LICENSE`](../LICENSE) Apache-2.0; `license = "Apache-2.0"` in [`moon.mod`](../moon.mod). |
| 8 | AI use allowed; author explains choices | ✅ | [`docs/RETROSPECTIVE.md`](./RETROSPECTIVE.md) §3: what AI assistants produced vs. what the author decided (rule semantics, severities, scope cuts, fixtures, test strategy). |
| 9 | Clear boundaries (judging) | ✅ | [`SCOPE.md`](../SCOPE.md) in/out of scope; README *Scope* and *Roadmap* (roadmap items marked not implemented). |

## How to verify locally

```bash
export PATH="$HOME/.moon/bin:$PATH"
moon check
moon test                              # Total tests: 32, passed: 32, failed: 0.
scripts/gen_fixture_tests.sh --check   # fixtures_test.mbt is up to date
moon run cmd/main -- fixtures/ok/minimal.json;          echo $?   # 0
moon run cmd/main -- fixtures/bad/required_unknown.json; echo $?  # 1
```

## Known gaps (stated honestly)

- **No hosted CI.** The GitHub token used for this repo lacks the `workflow` scope, so the template workflow was removed (commit `d2901c4`) and checks run locally through [`.githooks/pre-commit`](../.githooks/pre-commit). See RETROSPECTIVE §4.
- Only the native backend is exercised for the CLI; the library itself has no I/O.
- Not a full JSON Schema validator by design.
