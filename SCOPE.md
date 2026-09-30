# SCOPE — agent-schema-lint v0.1

Issue-style range note for the MoonBit Sep 2026 hackathon (Idea A).

## Goal

Ship a **runnable first cut**: MoonBit library + native CLI that lints JSON Schema **text** for common LLM / Agent structured-output pitfalls, with diagnostics and non-zero exit on errors.

## In scope (v0.1)

- Parse JSON via `@json.parse`
- Rule engine returning `Diagnostic { path, code, message, severity }`
- Rules ASL001–ASL008 (see README); ASL009 (Warning) added in #6
- CLI: `moon run cmd/main -- [--format text|json] <file.json>`, exit codes 0 / 1 / 2
- ≥6 fixtures under `fixtures/{ok,warn,bad}/`, each exercised by `moon test`
- `moon test` green
- Apache-2.0 LICENSE + README

## Out of scope (v0.1)

- Full Draft 2020-12 / # validation
- OpenAI / Anthropic / Gemini online schema endpoints
- Auto-fix / rewrite
- MCP server or editor LSP
- WASM / web playground
- Publishing to mooncakes (optional)

## Non-goals forever (this hackathon)

- Running LLMs or calling provider APIs
- Becoming a general-purpose JSON Schema validator

## Success for D0/D1

- [x] Toolchain installed; `moon new` project at builds path
- [x] LICENSE + README + SCOPE
- [x] Diagnostic + lint engine + 8 rules
- [x] Fixtures + `moon test` green
- [x] CLI reports errors and exits 1 on bad input

## Success for final acceptance (2026-09-30)

- [x] Every fixture is tested automatically with its expected code (#2, PR #3)
- [x] Machine-readable `--format json` output + clear exit codes 0 / 1 / 2 (#4, PR #5)
- [x] ASL009 strict-mode `required` warning with fixture + tests (#6, PR #7)
- [x] CLI output order fixed for pipes (#12, PR #13)
- [x] README: why, real demo output, rule examples, testing, roadmap (#11)
- [x] `docs/RETROSPECTIVE.md` and `docs/ACCEPTANCE.md` (#11)
- [x] Future work tracked as issues, not implemented: #8, #9, #10
- [ ] Hosted CI (blocked: token has no `workflow` scope; local pre-commit hook instead)
