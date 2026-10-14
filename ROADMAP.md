# 路线图

## 已发布

- **v0.1.0（2026-09）** 通用规则 ASL001–ASL009，`--format json`，fixtures 回归测试。
- **v0.2.0（2026-10）**
  - 国产大模型专属规则：`--profile deepseek | kimi | qwen | glm`（ASL010、ASL1xx，均附官方文档依据）
  - 自动修复：`--fix` 离线确定性修复 + `--ai` 调用 OpenAI 兼容模型改写，重新 lint 后只采用更好的结果
  - 真实案例：8 个开源 MCP Server、77 个工具 schema 的体检报告

## 下一步

### v0.3（2026-11）：从"单个 schema"到"整个工具集"
- 直接读取 OpenAI `tools` 数组、MCP `tools/list` 结果、Anthropic tool 定义，一次检查全部工具。
- 工具级规则：函数名格式（如 Kimi `^[a-zA-Z_][a-zA-Z0-9-_]{2,63}$`）、工具数量上限、重名检测。
- 新增平台 profile：文心（ERNIE）、豆包、讯飞星火、MiniMax。
- 预编译二进制（Linux / macOS / Windows），无需安装 MoonBit 即可使用。

### v0.4（2026-12）：集成到开发流程
- GitHub Action / GitLab CI 模板，PR 中自动标注问题行。
- `--live` 可选模式：用真实 API 发一次最小请求，验证平台是否真的接受（需密钥）。
- VS Code 插件：编辑 schema 时实时提示。

### v1.0（2027 Q1）
- 规则集稳定，提供规则版本号和平台文档快照，便于追溯。
- WebAssembly 版本，可嵌入网页和 Agent 框架。

## 长期方向

- 与 MCP 生态合作：为热门 MCP Server 提交兼容国产模型的修复 PR。
- 建立"平台 schema 兼容性"公开数据集，持续跟踪各平台规则变化。

欢迎在 Issue 中提需求，被点赞多的需求会优先排期。
