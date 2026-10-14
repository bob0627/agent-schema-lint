# 贡献指南

欢迎提 Issue 和 PR！本项目用 [MoonBit](https://www.moonbitlang.com/) 编写，目标是帮开发者在发布前发现"大模型工具 schema 在某个平台上会出错"的问题。

## 开发环境

```bash
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
export PATH="$HOME/.moon/bin:$PATH"
git clone https://github.com/bob0627/agent-schema-lint && cd agent-schema-lint
moon check && moon test
```

## 提交前必须通过

```bash
moon fmt          # 格式化
moon info         # 更新 pkg.generated.mbti（公开 API 变化要一起提交）
moon test         # 全部测试通过
scripts/gen_fixture_tests.sh --check   # 改了 fixtures/ 时
```

## 流程

1. 先开 Issue 说明问题或想法（小修复可直接 PR）。
2. 从 `master` 拉分支：`feat/...`、`fix/...`、`docs/...`。
3. 一个 PR 只做一件事，标题用 `feat: / fix: / docs: / chore:` 前缀。
4. 维护者 review 后合并，合并方式为 merge commit。

## 新增或修改规则

- 规则编号：通用规则 `ASL0xx`，平台规则 `ASL1xx`（DeepSeek 10x、Kimi 11x、Qwen 12x、GLM 13x，新平台按顺序分配）。
- **平台规则必须附官方文档链接和核对日期**，写进 `docs/PROFILES.md`。没有文档依据的只能是 warning。
- 每条规则至少一个"会报"和一个"不会报"的测试；能自动修复的，在 `fix.mbt` 加修复并测试幂等。
- 如果发现误报，请附上真实 schema（可以放到 `cases/`），我们会优先处理。

## 新增真实案例

用 `scripts/dump_mcp_schemas.py` 采集 MCP Server 的工具 schema，放到 `cases/mcp-servers/<server>/`，运行 `scripts/run_cases.py` 并更新 `docs/CASES.md`。

## 行为准则

参与本项目即表示同意遵守 [行为准则](CODE_OF_CONDUCT.md)。
