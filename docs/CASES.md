# 真实案例报告：8 个热门开源 MCP Server、77 个工具 schema

> 采集日期：2026-10-14（北京时间）。数据和脚本都在仓库里，可完整复现。

## 1. 数据来源

我们直接启动开源 MCP Server，通过 MCP 协议的 `tools/list` 拿到每个工具**实际下发给大模型**的 `inputSchema`（不是手抄、不是从源码猜），存到 `cases/mcp-servers/<server>/<tool>.json`。

| server | 包 / 版本 | 上游仓库 | 工具数 |
| --- | --- | --- | --- |
| filesystem | `@modelcontextprotocol/server-filesystem` 1.0.0 | github.com/modelcontextprotocol/servers | 14 |
| memory | `@modelcontextprotocol/server-memory` 1.0.0 | 同上 | 9 |
| everything | `@modelcontextprotocol/server-everything` 1.0.0 | 同上 | 13 |
| sequential-thinking | `@modelcontextprotocol/server-sequential-thinking` 1.0.0 | 同上 | 1 |
| fetch | `mcp-server-fetch` 2026.10.10（PyPI） | 同上 | 1 |
| git | `mcp-server-git` 2026.10.10（PyPI） | 同上 | 12 |
| time | `mcp-server-time` 2026.10.10（PyPI） | 同上 | 2 |
| playwright | `@playwright/mcp` 0.0.83 | github.com/microsoft/playwright-mcp | 25 |

复现：

```bash
python3 scripts/dump_mcp_schemas.py filesystem npx -y @modelcontextprotocol/server-filesystem /tmp/x
moon build --target native
python3 scripts/run_cases.py      # 生成 cases/results.json 和下面的表格
```

## 2. 总体结果

"有 error" 指把该 schema 原样发给对应平台的 strict / 结构化模式时，**按官方文档会被拒绝或不受支持**（依据见 [PROFILES.md](PROFILES.md)）。

| profile | 有 error 的 schema | --fix 后仍有 error | warning 总数（前→后） |
| --- | --- | --- | --- |
| generic | 0/77 | 0/77 | 152 → 9 |
| deepseek | 72/77 | 1/77 | 197 → 52 |
| kimi | 14/77 | 0/77 | 197 → 32 |
| qwen | 1/77 | 0/77 | 197 → 54 |
| glm | 0/77 | 0/77 | 197 → 54 |

按 server 统计（原样 schema 中有 error 的工具数）：

| server | tools | generic | deepseek | kimi | qwen | glm |
| --- | --- | --- | --- | --- | --- | --- |
| everything | 13 | 0 | 13 | 1 | 0 | 0 |
| fetch | 1 | 0 | 1 | 1 | 0 | 0 |
| filesystem | 14 | 0 | 14 | 0 | 0 | 0 |
| git | 12 | 0 | 12 | 12 | 0 | 0 |
| memory | 9 | 0 | 9 | 0 | 0 | 0 |
| playwright | 25 | 0 | 20 | 0 | 1 | 0 |
| sequential-thinking | 1 | 0 | 1 | 0 | 0 | 0 |
| time | 2 | 0 | 2 | 0 | 0 | 0 |

## 3. 关键发现

1. **同一份工具定义，在 DeepSeek strict 模式下 77 个里有 72 个过不了。**
   最主要的原因是 MCP 工具普遍有可选参数（144 处 ASL102：属性不在 required 里 / 没有 `additionalProperties: false`）。这在 OpenAI 非 strict 模式下没问题，但一旦开启 DeepSeek 的 `strict: true`，服务端会直接报错。
2. **Python 生态（Pydantic 生成）的工具全军覆没在 Kimi 上。**
   `mcp-server-git` / `mcp-server-fetch` 的 schema 每一层都带 `title`（共 45 处），Kimi 的 MFJS 规范明确不支持 `title`；它们还用 `anyOf: [{type: string}, {type: null}]` 表示可选参数，DeepSeek strict 不支持 `null` 类型（13 处）。
   例：`git_branch` 的 `contains` 参数——`{"anyOf":[{"type":"string"},{"type":"null"}],"default":null,"title":"Contains"}`。
3. **常见的长度 / 格式约束会被国产平台拒绝。**
   `fetch` 的 `url` 带 `minLength: 1` 和 `format: "uri"`；`read_multiple_files` 的 `paths` 带 `minItems: 1`。DeepSeek strict 不支持 `minLength/minItems`，`format` 只支持 email/hostname/ipv4/ipv6/uuid。
4. **通义千问踩中 1 处 400：** Playwright 的 `browser_drop.data` 用了 `propertyNames`，百炼文档列为"不支持，返回 400"。
5. **45 个参数没有 description（ASL010）**，集中在 filesystem（18）和 git（20）。模型只能靠参数名猜含义，这是"填错参数"的常见来源，也是 `--ai` 要解决的部分。
6. **8 个无参数工具** 的 `properties` 为空。工具调用里这是合法写法，所以 v0.2 起 ASL004 对根级空 properties 只给 warning（初版误报为 error，这个案例让我们修正了规则）。

## 4. 自动修复效果（`--fix`，离线、确定性）

- DeepSeek：有 error 的 schema 从 **72 → 1**。修复方式：补 `additionalProperties: false`、全部参数加入 required、去掉 null 分支、类型数组改 anyOf、把 `minLength`/`format` 等写进 description。
  唯一剩下的是 Playwright `browser_drop.data`——它本质上是"MIME 类型 → 字符串"的字典，strict 模式下没有等价表达，需要人或 AI 改结构（例如改成 `[{mime, value}]` 数组）。这正是 `--ai` 的用武之地。
- Kimi：**14 → 0**（`title` 合并进 description，`format` 写进 description）。
- 通义千问：**1 → 0**。
- 修复是幂等的，且每一步都打印改动日志，方便代码审查。

## 5. AI 修复的定位

确定性规则只做"不改变语义"的安全修复。剩下两类问题交给 `--ai`（任意 OpenAI 兼容模型，默认 DeepSeek）：

- 45 个缺失的参数说明（ASL010）：需要读懂工具用途才能写好；
- 需要改结构的 schema（如上面的字典参数）。

AI 的输出会被重新 lint，**只在问题严格减少时才采用**，否则保留离线结果。详见 [FIX.md](FIX.md)。

## 5.1 真实 AI 修复运行（Kimi Code，2026-10-14）

配置（不含密钥）：

```bash
export ASL_AI_API_KEY=...                                # Kimi Code 密钥
export ASL_AI_BASE_URL=https://api.kimi.com/coding/v1
export ASL_AI_MODEL=kimi-for-coding                       # 推理模型，仅思考模式
agent-schema-lint --fix --ai --profile deepseek cases/mcp-servers/playwright/browser_drop.json
```

| schema | profile | 原样 | `--fix` 后 | `--ai` 后 | 耗时 |
| --- | --- | --- | --- | --- | --- |
| playwright/browser_drop | deepseek | 4 error / 4 warning | 1 error / 1 warning | **0 / 0（已采用）** | 16 s |
| filesystem/edit_file | deepseek | 3 error / 5 warning | 0 / 2 | **0 / 0（已采用）** | 14 s |
| git/git_log | deepseek | 6 error / 6 warning | 0 / 2 | **0 / 0（已采用）** | 10 s |
| filesystem/directory_tree | kimi | 0 error / 4 warning | 0 / 2 | **0 / 0（已采用）** | 16 s |
| git/git_log | kimi | 5 error / 6 warning | 0 / 0 | 无需调用 AI | 0 s |
| sequential-thinking | deepseek | 9 error / 6 warning | 0 / 0 | 无需调用 AI | 0 s |

AI 改写结果保存在 `cases/ai-runs/`。4 个被采用的结果都保留了原有的全部参数名。

**亮点：唯一修不了的 browser_drop。** 它的 `data` 参数是"MIME 类型 → 字符串"的字典，DeepSeek strict 模式无法表达。模型把它改写成了 `[{"key": "text/plain", "value": "hello"}]` 形式的数组，并为每个字段写了说明。这是确定性规则做不到的结构性修复。注意，这会改变工具的调用格式，服务端需要配合调整，所以应当人工审核后再采用。

**真实运行发现并修复的问题（PR #19）：**
1. `kimi-for-coding` 只接受默认 temperature（发送 `temperature: 0` 会返回 400）。现在请求里不再发送 temperature。
2. 推理模型会返回 `reasoning_content`。工具只读取 `content`，有测试覆盖。
3. **护栏漏洞。** 第一次运行时，模型把 `data` 改成了空 object（`properties: {}`）来"躲过"规则。error 数没变，warning 减少了，于是被旧护栏采用了。现在新增一条护栏：AI 结果不能出现原来没有的错误类型。同时在提示词里要求把字典改成键值对数组。重跑后得到了上面的正确结果。
4. 非 200 响应现在会打印截断后的错误信息，方便排查。

## 6. 局限

- 规则依据的是各平台 2026-10-14 的公开文档；GLM 未公开 strict 子集，因此只给 warning。
- 体检结论是"按官方文档会被拒绝"，没有把 77 个 schema 逐一发给各平台做真实请求验证（列入 [ROADMAP](../ROADMAP.md)）。AI 修复已用真实的 Kimi Code 接口跑过（见 5.1）。
- 上游 schema 版权归原项目所有，此处仅作为测试数据引用。
