# 国产大模型规则（Provider Profiles）

`--profile` 在通用规则 ASL001–ASL009 之上，叠加某一家模型平台的专属检查。
同一份 schema 在 OpenAI 上能用，换到 DeepSeek / Kimi / 通义千问 / 智谱 GLM 时，
经常因为平台支持的 JSON Schema 子集不同而直接报 400，或者被静默忽略。

```bash
moon run cmd/main -- --profile deepseek tool.json
moon run cmd/main -- --profile kimi --format json tool.json
```

| profile | 别名 | 规则 | 级别 |
| --- | --- | --- | --- |
| 所有平台 profile | | ASL010 属性缺少 `description`（模型靠它来填参数） | warning |
| `deepseek` | | ASL101 strict 模式不支持的关键字 / 类型 / format | error |
| | | ASL102 strict 模式要求每个 object 全部属性 required 且 `additionalProperties: false` | error |
| `kimi` | `moonshot` | ASL111 MFJS 不支持的关键字、非根级 `$defs`、外部 `$ref`、混合类型 enum | error |
| `qwen` | `dashscope` `bailian` | ASL121 strict 结构化输出会返回 400 的关键字 | error |
| `glm` | `zhipu` | ASL131 官方文档未说明支持的关键字（建议实测） | warning |

## 依据（2026-10-14 核对）

### DeepSeek — Function Calling `strict` 模式（Beta）
来源：<https://api-docs.deepseek.com/guides/tool_calls>（`strict` Mode 一节）

- 需使用 `base_url=https://api.deepseek.com/beta`，每个 function 设置 `strict: true`；服务端会校验 schema，不合规直接报错。
- 支持的类型：object、string、number、integer、boolean、array、enum、anyOf（以及 `$ref`/`$def`）。
- object：所有属性必须 required，且 `additionalProperties` 必须为 `false`。→ ASL102
- string：支持 `pattern`、`format`（仅 email / hostname / ipv4 / ipv6 / uuid）；**不支持** `minLength`、`maxLength`。→ ASL101
- array：**不支持** `minItems`、`maxItems`。→ ASL101
- 文档未列出 `oneOf` / `allOf` / `not` / `if-then-else` / `prefixItems` / `patternProperties` / `null` 类型，本工具按"不支持"报错。

### Kimi（Moonshot）— MFJS
来源：<https://platform.kimi.ai/docs/api/tool-use>，<https://github.com/MoonshotAI/walle/blob/main/docs/mfjs-spec.md>

- tools 的 `strict` 默认为 `true`，`parameters` 必须符合 MFJS（Moonshot Flavored JSON Schema）。
- 不支持 `title`、`$comment`、`format` 等元数据注解；不支持 `prefixItems`、`unevaluatedItems`；不支持 `exclusiveMinimum`、`exclusiveMaximum`、`minContains`、`maxContains`。→ ASL111
- `$defs` 必须定义在根级；`$ref` 只能引用文档内部。→ ASL111
- enum 只支持 float / int / str，且不能混合类型。→ ASL111
- 函数名需匹配 `^[a-zA-Z_][a-zA-Z0-9-_]{2,63}$`（本工具只检查 schema，不检查函数名，见 ROADMAP）。

### 通义千问（阿里云百炼）— 结构化输出 strict 模式
来源：<https://help.aliyun.com/zh/model-studio/qwen-structured-output>（"支持的 JSON Schema 关键字"）

- 标记为"不支持"的关键字提交后返回 400：`multipleOf`、`uniqueItems`、`contains`、`minContains`、`maxContains`、`additionalItems`、`patternProperties`、`propertyNames`。→ ASL121
- 外部 URL `$ref` 不报错但不生效。

### 智谱 GLM
来源：<https://docs.bigmodel.cn/cn/guide/capabilities/function-calling>

- tools 遵循 OpenAI 协议，官方文档只展示了 type / properties / required / enum / description 等基础写法，未公布 strict 模式和支持子集。
- 因此 ASL131 只给 **warning**：`oneOf`、`allOf`、`not`、`if/then/else`、`patternProperties`、`prefixItems`、`$ref` 属于"文档未说明"，建议用真实请求验证。

## 维护说明
平台文档会更新。每条规则改动请在 PR 中附上文档链接和核对日期，并同步更新本页。
