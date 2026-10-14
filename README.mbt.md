# agent-schema-lint

**大模型工具 schema 的"体检 + 自动修复"工具，专门适配国产大模型。**

同一份 Function Calling / MCP 工具定义，在 OpenAI 上能用，换到 DeepSeek、Kimi、通义千问、智谱 GLM 时经常直接报 400，或者参数被模型填错。`agent-schema-lint` 在发布前就把这些问题找出来，并自动修好。

- 🔍 **国产模型专属规则**：`--profile deepseek | kimi | qwen | glm`，每条规则附官方文档依据（[docs/PROFILES.md](docs/PROFILES.md)）
- 🛠 **自动修复**：`--fix` 离线确定性修复；`--ai` 调用任意 OpenAI 兼容模型（默认 DeepSeek）补写参数说明、改结构，**重新 lint 后只采用更好的结果**（[docs/FIX.md](docs/FIX.md)）
- 📊 **真实案例**：8 个热门开源 MCP Server 的 77 个工具里，72 个过不了 DeepSeek strict 模式；`--fix` 后只剩 1 个（[docs/CASES.md](docs/CASES.md)）
- ⚙️ 用 MoonBit 编写，原生二进制、离线运行，退出码和 `--format json` 便于接入 CI

### 30 秒上手

```bash
export PATH="$HOME/.moon/bin:$PATH"
git clone https://github.com/bob0627/agent-schema-lint && cd agent-schema-lint
moon run cmd/main -- --profile deepseek cases/mcp-servers/git/git_branch.json        # 体检
moon run cmd/main -- --fix --profile deepseek cases/mcp-servers/git/git_branch.json  # 修复
ASL_AI_API_KEY=sk-... moon run cmd/main -- --fix --ai --profile kimi your_tool.json  # AI 修复
```

参与贡献见 [CONTRIBUTING.md](CONTRIBUTING.md)，路线图见 [ROADMAP.md](ROADMAP.md)，更新日志见 [CHANGELOG.md](CHANGELOG.md)。

---

## English


Offline **JSON Schema subset linter** for LLM structured-output / Agent tool schemas.

Built with [MoonBit](https://www.moonbitlang.com/). Linting is fully offline; the optional `--fix --ai` mode calls an OpenAI-compatible model you configure.

## Why

Agent tool definitions and structured-output schemas are usually hand-written JSON.
Many mistakes are *valid JSON Schema* but still break at request time: strict provider
modes reject objects without `additionalProperties: false` or with properties missing
from `required`, a typo in `required` or a dangling `$ref` is silently ignored, and an
empty `enum` makes a field impossible to fill. These failures show up late — as an API
error or as a model that "ignores" a field. `agent-schema-lint` catches this class of
problem **offline, before the schema ships**, with stable codes and JSON paths that fit
into CI.

It is deliberately **not** a full JSON Schema validator (see [Scope](#scope)).

## Install / build

```bash
# MoonBit toolchain (Linux/macOS)
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
export PATH="$HOME/.moon/bin:$PATH"

git clone https://github.com/bob0627/agent-schema-lint
cd agent-schema-lint
moon check
moon test
```

The CLI targets the native backend (`preferred_target = "native"`).

## Quick demo

Real output captured from this repo (`moon run`, stdout and stderr combined):

```text
$ moon run cmd/main -- fixtures/ok/minimal.json
ok: fixtures/ok/minimal.json
$ echo $?
0

$ moon run cmd/main -- fixtures/bad/required_unknown.json
error[ASL007] $.required[1]: required field "missing" is not declared in properties
lint failed: 1 finding(s) in fixtures/bad/required_unknown.json
$ echo $?
1

$ moon run cmd/main -- --format json fixtures/bad/required_unknown.json
[{"path":"$.required[1]","code":"ASL007","message":"required field \"missing\" is not declared in properties","severity":"error"}]
$ echo $?
1

$ moon run cmd/main -- fixtures/warn/optional_property.json
warning[ASL009] $.properties.limit: property "limit" is not listed in required; strict structured-output modes require every property (make it nullable instead of optional)
ok with warnings: fixtures/warn/optional_property.json
$ echo $?
0
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

Library API (pure, no I/O):

```mbt nocheck
let diags = @agent-schema-lint.lint(schema_text)
if @agent-schema-lint.has_errors(diags) {
  // fail CI
}
println(@agent-schema-lint.diagnostics_to_json(diags)) // JSON array string
```

The full public interface is in [`pkg.generated.mbti`](./pkg.generated.mbti).

## Rules

Paths use `$` for the root, e.g. `$.properties.user.required[0]`.

| Code | Severity | Check | Minimal trigger |
|------|----------|-------|-----------------|
| ASL001 | Error | Invalid JSON, or root is not an object | `{not-json`, `[1,2]` |
| ASL002 | Error | Root `type` missing or not `"object"` | `{"type": "string"}` |
| ASL003 | Error | Nested schema-like object missing `type` (and not a `$ref`) | `"nested": {"properties": {…}}` |
| ASL004 | Error | `properties` empty or not an object | `"properties": {}` |
| ASL005 | Error | `enum` empty or not an array | `"enum": []` |
| ASL006 | Warning | Object type missing / non-false `additionalProperties` (strict-agent hint) | `{"type": "object", "properties": {…}}` |
| ASL007 | Error | `required` entry not declared in `properties` (or not strings) | `"required": ["a", "missing"]` |
| ASL008 | Error | Local `#/$defs/…` or `#/definitions/…` `$ref` dangling | `{"$ref": "#/$defs/Item"}` with no `Item` |
| ASL009 | Warning | Property declared in `properties` but not listed in `required` (strict modes require all) | `properties: {a, b}`, `required: ["a"]` |

Each rule has at least one fixture under [`fixtures/`](./fixtures) (ASL001 is covered by unit tests).

Errors mean "this schema is broken for agent use"; warnings mean "this works in lenient
modes but is likely rejected by strict structured-output modes".

## Testing

```bash
moon test                             # 32 tests
scripts/gen_fixture_tests.sh --check  # fixtures_test.mbt is in sync with fixtures/
```

- `agent-schema-lint_test.mbt` — rule unit tests with inline schemas.
- `json_output_test.mbt` — JSON output format (`diagnostics_to_json`, escaping, severity labels).
- `fixtures_test.mbt` — **generated** from every file in `fixtures/` by
  [`scripts/gen_fixture_tests.sh`](./scripts/gen_fixture_tests.sh):
  - `fixtures/ok/*.json` must have no Error,
  - `fixtures/warn/*.json` must have no Error and the Warning code listed in `fixtures/warn/expected.txt`,
  - `fixtures/bad/*.json` must have an Error with the code listed in `fixtures/bad/expected.txt`.

Fixtures are embedded as `#|` multiline strings instead of being read at test time, so
tests stay deterministic and backend-independent. After editing fixtures, rerun the
script; `--check` (also run by [`.githooks/pre-commit`](./.githooks)) fails if the
generated file is stale, and a new bad/warn fixture without an expected code fails generation.

## Scope

See [SCOPE.md](./SCOPE.md). Short version:

**In:** static subset lint for agent / structured-output schemas; CLI + library; fixtures + `moon test`.

**Out:** full JSON Schema validation, live provider API checks, auto-fix, MCP server, WASM demo.

## Roadmap

Ideas only — **not implemented**, tracked as `future-work` issues:

- [ ] Warn on keywords unsupported by strict modes (`oneOf`, `patternProperties`, …) — [#8](https://github.com/bob0627/agent-schema-lint/issues/8)
- [ ] Provider rule packs (`--profile generic|strict`, static tables, still offline) — [#9](https://github.com/bob0627/agent-schema-lint/issues/9)
- [ ] Auto-fix suggestions for mechanical findings (ASL006, ASL009) — [#10](https://github.com/bob0627/agent-schema-lint/issues/10)

## Project docs

- [SCOPE.md](./SCOPE.md) — boundaries
- [docs/ACCEPTANCE.md](./docs/ACCEPTANCE.md) — hackathon acceptance checklist with evidence
- [docs/RETROSPECTIVE.md](./docs/RETROSPECTIVE.md) — decisions, AI usage, problems hit (中文 / English)

## License

Apache-2.0 — see [LICENSE](./LICENSE).
