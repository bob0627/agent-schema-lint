# agent-schema-lint

Offline **JSON Schema subset linter** for LLM structured-output / Agent tool schemas.

Built with [MoonBit](https://www.moonbitlang.com/). No network calls, no model calls — static rules only.

## Install / build

```bash
# MoonBit toolchain (Linux/macOS)
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
source ~/.bashrc   # or export PATH="$HOME/.moon/bin:$PATH"

cd agent-schema-lint
moon check
moon test
```

## Usage

```bash
moon run cmd/main -- [--format text|json] <schema.json>

# Examples
moon run cmd/main -- fixtures/ok/minimal.json
moon run cmd/main -- fixtures/bad/empty_props.json
moon run cmd/main -- --format json fixtures/bad/required_unknown.json
```

- `--format text` (default): one line per finding, `severity[CODE] json.path: message`.
- `--format json`: a single JSON array on stdout, one object per finding with
  `path`, `code`, `message`, `severity` (`"error"` / `"warning"`); `[]` when clean.
  Intended for CI tools and editors.

Exit codes:

| Code | Meaning |
|------|---------|
| 0 | No Error findings (warnings allowed) |
| 1 | At least one Error finding |
| 2 | Usage error (missing file, unknown `--format`) or file cannot be read |

In text mode the `lint failed: …` summary goes to stderr, so stdout only carries findings.

Library API (pure):

```mbt nocheck
let diags = @agent-schema-lint.lint(schema_text)
if @agent-schema-lint.has_errors(diags) {
  // fail CI
}
println(@agent-schema-lint.diagnostics_to_json(diags)) // JSON array string
```

## Rules

| Code | Severity | Check |
|------|----------|--------|
| ASL001 | Error | Invalid JSON, or root is not an object |
| ASL002 | Error | Root `type` missing or not `"object"` |
| ASL003 | Error | Nested schema-like object missing `type` (and not a `$ref`) |
| ASL004 | Error | `properties` empty or not an object |
| ASL005 | Error | `enum` empty or not an array |
| ASL006 | Warning | Object type missing / non-false `additionalProperties` (strict-agent hint) |
| ASL007 | Error | `required` entry not declared in `properties` |
| ASL008 | Error | Local `#/$defs/…` or `#/definitions/…` `$ref` dangling |
| ASL009 | Warning | Property declared in `properties` but not listed in `required` (strict modes require all) |

## Scope

See [SCOPE.md](./SCOPE.md). Short version:

**In:** static subset lint for agent / structured-output schemas; CLI + library; fixtures + `moon test`.

**Out:** full JSON Schema validation, live provider API checks, auto-fix, MCP server, WASM demo (maybe later).

## License

Apache-2.0
