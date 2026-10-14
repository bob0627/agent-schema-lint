///|
/// Result of a deterministic fix pass.
pub(all) struct FixResult {
  /// Fixed schema, pretty-printed JSON.
  fixed : String
  /// Human-readable change log, one entry per edit.
  changes : Array[String]
}

///|
/// Apply safe, deterministic fixes for `profile`. Returns `None` when the
/// input is not a JSON object (nothing can be fixed safely).
///
/// Fixes: missing root / object `type`, `additionalProperties` → false,
/// unknown `required` entries removed, all properties made required, and
/// provider-unsupported keywords moved into `description` text so the
/// constraint is not silently lost.
pub fn fix_schema(schema_text : StringView, profile : Profile) -> FixResult? {
  let parsed = @json.parse(schema_text) catch { _ => return None }
  guard parsed is Object(root) else { return None }
  let changes : Array[String] = []
  visit_schema(root, "$", true, fn(node, path, is_root) {
    fix_node(node, path, is_root, profile, changes)
  })
  Some({ fixed: parsed.stringify(indent=2), changes, })
}

///|
fn fix_node(
  node : Map[String, Json],
  path : String,
  is_root : Bool,
  profile : Profile,
  changes : Array[String],
) -> Unit {
  if !node.contains("type") && !node.contains("$ref") {
    if is_root || node.contains("properties") {
      node.set("type", "object")
      changes.push("\{path}: 补充 type: \"object\"")
    }
  }
  if node.get("type") is Some(String("object")) {
    match node.get("additionalProperties") {
      Some(False) => ()
      Some(Object(_)) => ()
      _ => {
        node.set("additionalProperties", false)
        changes.push("\{path}: additionalProperties 设为 false")
      }
    }
  }
  if node.get("properties") is Some(Object(props)) {
    let names : Array[String] = []
    props.each(fn(name, _) { names.push(name) })
    let old : Array[String] = []
    if node.get("required") is Some(Array(arr)) {
      for item in arr {
        if item is String(s) {
          old.push(s)
        }
      }
    }
    let req : Array[Json] = []
    for s in old {
      if props.contains(s) {
        req.push(Json::string(s))
      } else {
        changes.push("\{path}.required: 删除未声明的字段 \"\{s}\"")
      }
    }
    for n in names {
      if !old.contains(n) {
        req.push(Json::string(n))
        changes.push(
          "\{path}.required: 加入 \"\{n}\"（strict 模式要求全部必填；若语义上可选，请在描述中说明可传空值）",
        )
      }
    }
    node.set("required", Json::array(req))
  }
  let strip = match profile {
    DeepSeek =>
      deepseek_unsupported.filter(fn(k) {
        k != "oneOf" &&
        k != "allOf" &&
        k != "not" &&
        k != "if" &&
        k != "then" &&
        k != "else" &&
        k != "prefixItems" &&
        k != "patternProperties"
      })
    Kimi =>
      kimi_unsupported.filter(fn(k) {
        k != "prefixItems" && k != "$schema" && k != "$id"
      })
    Qwen => qwen_unsupported.filter(fn(k) { k != "contains" })
    _ => []
  }
  for key in strip {
    if profile == DeepSeek && key == "format" {
      continue
    }
    move_to_description(node, path, key, changes)
  }
  if profile == DeepSeek {
    match node.get("format") {
      Some(String(f)) if !deepseek_formats.contains(f) =>
        move_to_description(node, path, "format", changes)
      _ => ()
    }
    drop_null_branches(node, path, changes)
    if node.get("oneOf") is Some(arr) && !node.contains("anyOf") {
      node.remove("oneOf")
      node.set("anyOf", arr)
      changes.push(
        "\{path}: oneOf 改为 anyOf（DeepSeek strict 只支持 anyOf）",
      )
    }
  }
}

///|
fn move_to_description(
  node : Map[String, Json],
  path : String,
  key : String,
  changes : Array[String],
) -> Unit {
  guard node.get(key) is Some(value) else { return }
  node.remove(key)
  let note = match value {
    String(s) => "\{key}: \{s}"
    _ => "\{key}: \{value.stringify()}"
  }
  if key == "title" && !node.contains("description") {
    node.set("description", value)
  } else {
    let desc = match node.get("description") {
      Some(String(d)) => "\{d}（\{note}）"
      _ => "（\{note}）"
    }
    node.set("description", Json::string(desc))
  }
  changes.push("\{path}.\{key}: 平台不支持，已移入 description")
}

///|
/// Build an OpenAI-compatible `/chat/completions` request body asking the
/// model to rewrite `schema` so that `diags` disappear for `profile`.
/// No `temperature` is sent: reasoning models (e.g. kimi-for-coding)
/// reject anything but their default. The model may only return JSON; the caller re-lints and keeps the old
/// schema if the answer is not strictly better.
pub fn ai_fix_request(
  schema : String,
  diags : ArrayView[Diagnostic],
  profile : Profile,
  model : String,
) -> Json {
  let findings = StringBuilder()
  for d in diags {
    findings.write_string("- \{d.format()}\n")
  }
  let system =
    #|你是 JSON Schema 修复器，专门修复大模型 Function Calling / 结构化输出用的工具参数 schema。
    #|规则：
    #|1. 只输出修复后的完整 JSON Schema 对象本身，不要任何解释或 Markdown。
    #|2. 不得改变字段名、不得删除字段、不得改变字段类型的含义。
    #|3. 为缺少 description 的字段补写简洁、准确的中文 description（说明含义、格式、示例）。
    #|4. 目标平台不支持的关键字，删除并把约束写进 description。
    #|5. 每个 object 都要 additionalProperties: false，且全部属性列入 required。
    #|6. 动态键的字典（additionalProperties 为 schema）在 strict 模式下无法表达时，改写成
    #|   由 {"key": ..., "value": ...} 对象组成的数组，并在 description 中说明；不要把它改成空 object。
  let user = "目标平台 profile: \{profile.name()}\n\nlint 发现的问题:\n\{findings.to_string()}\n待修复 schema:\n\{schema}"
  {
    "model": model.to_json(),
    "response_format": { "type": "json_object" },
    "messages": [
      { "role": "system", "content": system.to_json() },
      { "role": "user", "content": user.to_json() },
    ],
  }
}

///|
/// Extract the schema JSON text from an OpenAI-compatible chat completion
/// response. Tolerates a ```json fenced answer. `None` if malformed.
pub fn ai_fix_extract(response_text : StringView) -> String? {
  let resp = @json.parse(response_text) catch { _ => return None }
  guard resp
    is Object(
      { "choices": Array([Object({ "message": Object(msg), .. }), ..]), .. }
    ) else {
    return None
  }
  guard msg.get("content") is Some(String(content)) else { return None }
  let mut s = content.trim().to_owned()
  if s.has_prefix("```") {
    let lines = s.split("\n").map(fn(l) { l.to_owned() }).collect()
    let body = lines.filter(fn(l) { !l.trim().has_prefix("```") })
    s = body.join("\n")
  }
  let check = @json.parse(s) catch { _ => return None }
  guard check is Object(_) else { return None }
  Some(check.stringify(indent=2))
}

///|
/// Count (errors, warnings).
pub fn count_findings(diags : ArrayView[Diagnostic]) -> (Int, Int) {
  let mut e = 0
  let mut w = 0
  for d in diags {
    if d.severity == Error {
      e = e + 1
    } else {
      w = w + 1
    }
  }
  (e, w)
}

///|
/// Accept an AI rewrite only if it has no more errors and no more
/// warnings than the deterministic result, is strictly better, and adds no
/// new kind of error.
pub fn ai_fix_is_better(
  before : ArrayView[Diagnostic],
  after : ArrayView[Diagnostic],
) -> Bool {
  let (be, bw) = count_findings(before)
  let (ae, aw) = count_findings(after)
  // The rewrite must not introduce a kind of error that was not there
  // before (e.g. emptying an object to dodge a strict-mode rule).
  let old_codes : Map[String, Bool] = Map([])
  for d in before {
    if d.severity == Error {
      old_codes.set(d.code, true)
    }
  }
  for d in after {
    if d.severity == Error && !old_codes.contains(d.code) {
      return false
    }
  }
  ae <= be && aw <= bw && (ae < be || aw < bw)
}

///|
/// DeepSeek strict mode has no `null` type. Pydantic-style optionals
/// (`anyOf: [{...}, {"type": "null"}]`) lose the null branch; a single
/// remaining branch is inlined. Nullability is noted in `description`.
fn drop_null_branches(
  node : Map[String, Json],
  path : String,
  changes : Array[String],
) -> Unit {
  if node.get("type") is Some(Array(types)) {
    let rest = types.filter(fn(t) { !(t is String("null")) })
    if rest is [only] && rest.length() < types.length() {
      node.set("type", only)
      changes.push(
        "\{path}.type: 去掉 \"null\"（DeepSeek strict 不支持 null 类型）",
      )
    }
  }
  if node.get("type") is Some(Array(types)) && !node.contains("anyOf") {
    node.remove("type")
    node.set(
      "anyOf",
      Json::array(types.map(fn(t) { Json::object(Map([("type", t)])) })),
    )
    changes.push(
      "\{path}.type: 类型数组改写为 anyOf（DeepSeek strict 只支持单一类型）",
    )
  }
  guard node.get("anyOf") is Some(Array(branches)) else { return }
  let kept = branches.filter(fn(b) {
    !(b is Object({ "type": String("null"), .. }))
  })
  if kept.length() == branches.length() || kept.is_empty() {
    return
  }
  node.remove("anyOf")
  if kept is [Object(only)] {
    only.each(fn(k, v) { if !node.contains(k) { node.set(k, v) } })
  } else {
    node.set("anyOf", Json::array(kept))
  }
  if node.get("default") is Some(Null) {
    node.remove("default")
  }
  let desc = match node.get("description") {
    Some(String(d)) => "\{d}（可为空：不需要时传空字符串或 0）"
    _ => "（可为空：不需要时传空字符串或 0）"
  }
  node.set("description", Json::string(desc))
  changes.push(
    "\{path}.anyOf: 去掉 null 分支（DeepSeek strict 不支持 null 类型）",
  )
}
