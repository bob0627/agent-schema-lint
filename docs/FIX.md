# 自动修复：`--fix` 与 AI 修复 `--ai`

```
lint ──► 确定性修复 ──► 重新 lint ──► (可选) AI 改写 ──► 再次 lint ──► 只在"更好"时采用
```

## 1. 确定性修复（离线、无需密钥）

```bash
moon run cmd/main -- --fix --profile deepseek tool.json            # 修复结果打印到 stdout
moon run cmd/main -- --fix --profile kimi tool.json -o fixed.json  # 写入文件
```

改动日志和前后问题数打印在 stderr。会做的修复：

| 问题 | 修复 |
| --- | --- |
| 根或含 `properties` 的节点缺 `type` | 补 `"type": "object"` |
| object 未设 / 设为 true 的 `additionalProperties` | 改为 `false` |
| `required` 中有未声明字段 | 删除 |
| 属性不在 `required` 中 | 加入（strict 模式要求），日志提示语义 |
| 平台不支持的约束（如 DeepSeek 的 `minLength`、Kimi 的 `title`/`format`、Qwen 的 `multipleOf`） | 删除关键字，把约束写进 `description`，约束信息不丢 |
| DeepSeek 的 `oneOf` | 改为 `anyOf` |

修复是幂等的：对修复结果再跑一遍不会产生新改动（有测试覆盖）。

## 2. AI 修复（OpenAI 兼容接口，可换任意国产模型）

确定性规则补不了的东西——比如给每个参数写**准确的中文说明**（ASL010），或重构组合结构——交给大模型：

```bash
export ASL_AI_API_KEY=sk-...                         # 也兼容 DEEPSEEK_API_KEY
export ASL_AI_BASE_URL=https://api.deepseek.com      # 默认值，可换成其他 OpenAI 兼容地址
export ASL_AI_MODEL=deepseek-flash                   # 默认值
moon run cmd/main -- --fix --ai --profile deepseek tool.json
```

其他平台示例（均为 OpenAI 兼容 `/chat/completions`）：

| 平台 | ASL_AI_BASE_URL | ASL_AI_MODEL 示例 |
| --- | --- | --- |
| DeepSeek | `https://api.deepseek.com` | `deepseek-flash` |
| Kimi | `https://api.moonshot.cn/v1` | 以平台控制台为准 |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | 如 `qwen-plus` |
| 智谱 GLM | `https://open.bigmodel.cn/api/paas/v4` | 如 `glm-4.5` 等 |

安全护栏：

- 提示词要求模型**只输出 JSON**、不得改字段名和类型含义；回答若带 ```json 代码块会自动剥离。
- 模型回答会被**重新 lint**。只有 error 和 warning 都不增加、且至少减少一个时才采用，否则丢弃并保留确定性结果。
- 没有密钥、网络失败、HTTP 非 200、回答不是合法 JSON 时，都会退回离线结果，命令不会因此失败。

## 3. 无密钥演示

`scripts/mock_llm.py` 是一个本地的 OpenAI 兼容模拟服务，用来演示和测试完整的 AI 闭环：

```bash
python3 scripts/mock_llm.py &
ASL_AI_API_KEY=mock ASL_AI_BASE_URL=http://127.0.0.1:18080 \
  moon run cmd/main -- --fix --ai --profile kimi fixtures/profiles/multi_provider.json
```

退出码：修复后仍有 error 为 1，否则为 0；输入不是 JSON 对象为 2。
