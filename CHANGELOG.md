# 更新日志

## v0.2.0 — 2026-10-14

### 新增
- `--profile deepseek|kimi|qwen|glm`：国产大模型专属规则 ASL010、ASL101、ASL102、ASL111、ASL121、ASL131（#15）
- `--fix` 离线确定性修复，`--ai` OpenAI 兼容模型改写 + 重新 lint 护栏，`-o/--output`（#16）
- 真实案例报告 docs/CASES.md：8 个开源 MCP Server、77 个工具 schema（#17）
- 治理文档：CONTRIBUTING、CODE_OF_CONDUCT、ROADMAP、Issue/PR 模板

### 变更
- ASL004：根级空 `properties`（无参数工具）由 error 改为 warning（来自真实案例的反馈）

## v0.1.0 — 2026-09-30
- 首个版本：ASL001–ASL009，`--format json`，fixtures 回归测试。
