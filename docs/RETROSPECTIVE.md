# 复盘 / Retrospective — agent-schema-lint（MoonBit 2026 年 9 月黑客松）

> 中文为主，文末附英文摘要。English summary at the end.

## 1. 目标

为 LLM 结构化输出 / Agent 工具调用的 JSON Schema 做一个**离线、静态、可放进 CI 的子集 linter**：
在 schema 发给模型提供方之前，就发现那些"JSON Schema 本身合法、但在 agent 场景下会出问题"的写法
（空 `enum`、`required` 拼错、悬空 `$ref`、严格模式下不被接受的 `additionalProperties` / 可选字段等）。

交付形态：MoonBit 库（`lint(StringView) -> Array[Diagnostic]`，纯函数、无 I/O）+ native CLI（退出码可用于 CI）。

## 2. 范围决策（做什么 / 不做什么）

| 决策 | 理由 |
|------|------|
| 只做**子集 lint**，不做完整 Draft 2020-12 校验 | 完整校验器工作量大且已有成熟实现；agent 场景的痛点是"合法但不可用"，而不是规范一致性。 |
| **完全离线**，不调用任何提供方 API / 模型 | 结果可复现、可放 CI；也避免把密钥和网络引入工具。 |
| 规则分 **Error / Warning** 两级 | Error = 对 agent 来说一定坏掉（例如 ASL007 `required` 指向不存在的字段）；Warning = 宽松模式可用、严格模式大概率被拒（ASL006、ASL009）。 |
| ASL009 定为 Warning 而非 Error | "每个 property 都必须在 `required` 中"是严格模式的要求，不是 JSON Schema 的要求；默认报错会误伤非严格用户。 |
| 不做 auto-fix、MCP server、WASM playground、提供方规则包 | 黑客松周期内优先"边界清晰 + 测试可靠 + 文档完整"。这些都记录为 future-work Issue（#8、#9、#10），**未实现**。 |
| CLI 退出码 0 / 1 / 2 | 1 只表示"有 Error 级发现"，用法错误和读文件失败用 2，CI 可以区分"schema 有问题"和"调用方式有问题"。 |

## 3. AI 如何参与 vs. 作者做了哪些决定

本项目使用了 AI 编程助手（Codex / LLM 类助手）。分工如下：

**AI 主要负责（作者逐一审阅后合入）：**

- 项目脚手架：`moon new` 之后的包结构、`Diagnostic` 结构体、规则函数的样板代码；
- 测试样板：内联 schema 的单元测试、JSON 输出测试；
- `scripts/gen_fixture_tests.sh` 生成脚本（把 fixture 以 `#|` 多行字符串嵌入 `fixtures_test.mbt`）；
- CLI 参数解析（`@argparse`）与退出码的实现细节；
- README / 本文档 / ACCEPTANCE.md 的初稿与排版。

**作者决定：**

- **规则语义**：哪些问题算 agent schema 的"坏味道"，每条规则是 Error 还是 Warning，报告在哪个 JSON path 上；
- **范围取舍**：不做完整校验器、不联网、不做 MCP / WASM / auto-fix（见上表）；
- **fixture 选择**：`fixtures/{ok,warn,bad}` 里每个文件对应一个具体的典型错误，`expected.txt` 中的期望代码先由 CLI 输出得到，再对照规则表人工确认；
- **测试策略**：选择"生成嵌入式测试 + `--check` 防漂移"，而不是在测试运行时读文件（保持测试确定、与后端无关）；
- 每个 PR 的合并：先在本地跑 `moon fmt && moon info && moon check && moon test` 全绿再推送。

## 4. 遇到的问题与处理

1. **推送 workflow 被拒（OAuth scope）**：模板自带的 Copilot workflow 文件需要 `workflow` 权限，而当前 token 没有该权限，首次推送被 GitHub 拒绝。
   处理：删除该 workflow（commit `d2901c4`），改用本地 `.githooks/pre-commit`（`moon check` + fixture 同步检查 + `moon test`）保证不推红。
   代价：目前仓库**没有云端 CI**，这一点在 ACCEPTANCE.md 中如实说明。
2. **fixture 没有被自动测试**：最初 `fixtures/` 只能手动用 CLI 跑，单元测试用的是另一份内联副本，二者可能漂移。
   处理：#2 / PR #3 —— 期望代码清单 + 生成脚本 + `--check`，每个 fixture 都进入 `moon test`。
3. **CLI 输出不干净**：Error 时打印原始的 `Failure(cmd/main/main.mbt:…)`，读文件失败打印原始 `OSError(...)`，且二者退出码都是 1。
   处理：#4 / PR #5 —— 清晰的 stderr 信息、退出码 2、`--format json`。
4. **管道输出顺序错乱**：录 README demo 时发现 `2>&1 | cat` 下 stderr 的汇总行出现在 stdout 的发现之前（stdout 被缓冲）。
   处理：#12 / PR #13 —— 所有输出统一走 `@stdio` 异步无缓冲写。
5. **格式化 / 编译器警告**：初始提交未经过当前版本 `moon fmt`；给 `Diagnostic` 实现 `ToJson` 时出现 `implicit_impl_as_method` 弃用警告。
   处理：单独的 `chore` 提交做格式化并纳入 `.mbti`；按警告提示补充 `pub extend … with ToJson::{to_json}`。

## 5. 下一步

- #8：对严格模式不支持的关键字（`oneOf`、`patternProperties` 等）给出 Warning；
- #9：提供方规则包（`--profile`），仍保持离线、静态表驱动；
- #10：为机械性问题（ASL006、ASL009）给出修复建议，先放进 JSON 输出；
- 在拿到 `workflow` 权限后补上云端 CI（运行 `moon test` 与 `scripts/gen_fixture_tests.sh --check`）。

---

## English summary

- **Goal:** an offline, static subset linter for LLM structured-output / agent tool JSON Schemas, usable from CI (MoonBit library + native CLI).
- **Scope decisions:** subset lint only (not a full validator); no network or model calls; Error = broken for agent use, Warning = likely rejected by strict modes (ASL006, ASL009); auto-fix / MCP / WASM / provider packs deferred to future-work issues #8–#10 (not implemented).
- **AI vs. author:** AI assistants (Codex / LLM tools) drafted scaffolding, test boilerplate, the fixture generator script, CLI plumbing and doc drafts. The author decided rule semantics and severities, scope cuts, fixture choices and expected codes, the embedded-fixture test strategy, and reviewed every change with `moon fmt/info/check/test` green before pushing.
- **Problems hit:** workflow push rejected for missing OAuth `workflow` scope → removed the Copilot workflow and used a local pre-commit hook (so there is no hosted CI yet); fixtures were not auto-tested → generated fixture tests (#2/PR #3); noisy CLI failures → clean stderr, exit 2, `--format json` (#4/PR #5); piped output ordering → unbuffered stdio (#12/PR #13); formatter drift and a deprecation warning → fixed in dedicated commits.
- **Next:** #8, #9, #10, and hosted CI once the token has `workflow` scope.
