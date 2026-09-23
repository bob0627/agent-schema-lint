# SCOPE — agent-schema-lint v0.1

Issue-style range note for the MoonBit Sep 2026 hackathon (Idea A).

## Goal

Ship a **runnable first cut**: MoonBit library + native CLI that lints JSON Schema **text** for common LLM / Agent structured-output pitfalls, with diagnostics and non-zero exit on errors.

## In scope (v0.1)

- Parse JSON via `@json.parse`
- Rule engine returning `Diagnostic { path, code, message, severity }`
- Rules ASL001–ASL008 (see README)
- CLI: `moon run cmd/main -- <file.json>`
- ≥6 fixtures under `fixtures/{ok,bad}/`
- `moon test` green
- Apache-2.0 LICENSE + README

## Out of scope (v0.1)

- Full Draft 2020-12 / # validation
- OpenAI / Anthropic / Gemini online schema endpoints
- Auto-fix / rewrite
- MCP server or editor LSP
- WASM / web playground (optional stretch after D3)
- Publishing to mooncakes (optional)

## Non-goals forever (this hackathon)

- Baidu map / farm-style demos
- Hosting a second product runtime beside GOSIM

## Success for D0/D1

- [x] Toolchain installed; `moon new` project at builds path
- [x] LICENSE + README + SCOPE
- [x] Diagnostic + lint engine + 8 rules
- [x] Fixtures + `moon test` green
- [x] CLI reports errors and exits 1 on bad input
