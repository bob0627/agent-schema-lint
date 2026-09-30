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
# Lint a schema file (exit 1 if any Error-severity finding)
moon run cmd/main -- path/to/schema.json

# Examples
moon run cmd/main -- fixtures/ok/minimal.json
moon run cmd/main -- fixtures/bad/empty_props.json
```

Library API (pure):

```mbt nocheck
let diags = @agent-schema-lint.lint(schema_text)
if @agent-schema-lint.has_errors(diags) {
  // fail CI
}
```

## Rules (v0.1)

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

## Scope

See [SCOPE.md](./SCOPE.md). Short version:

**In:** static subset lint for agent / structured-output schemas; CLI + library; fixtures + `moon test`.

**Out:** full JSON Schema validation, live provider API checks, auto-fix, MCP server, WASM demo (maybe later).

## License

Apache-2.0
