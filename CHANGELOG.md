# 更新日志

## v0.2.1 — 2026-10-14

### 修复
- AI 客户端兼容推理模型：不再发送 `temperature`（kimi-for-coding 只接受默认值），忽略 `reasoning_content`；非 200 时打印错误信息
- AI 护栏：改写结果不得引入新的错误类型；提示词要求把字典改写为键值对数组
- 用真实 Kimi Code 接口验证 AI 修复，结果见 docs/CASES.md 5.1 和 cases/ai-runs/

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
