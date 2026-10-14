///|
/// Target provider profile. `Generic` runs only the portable ASL001–ASL009
/// rules; the others add provider-specific checks (ASL010, ASL1xx).
/// Sources for every provider rule are listed in docs/PROFILES.md.
pub(all) enum Profile {
  Generic
  DeepSeek
  Kimi
  Qwen
  Glm
} derive(Eq)

///|
pub extend Profile with Eq::{equal, not_equal}

///|
/// Parse a profile name (case-insensitive): generic, deepseek, kimi
/// (alias moonshot), qwen (alias dashscope / bailian), glm (alias zhipu).
pub fn Profile::parse(name : String) -> Profile? {
  match name.to_lower() {
    "generic" | "openai" => Some(Generic)
    "deepseek" => Some(DeepSeek)
    "kimi" | "moonshot" => Some(Kimi)
    "qwen" | "dashscope" | "bailian" => Some(Qwen)
    "glm" | "zhipu" => Some(Glm)
    _ => None
  }
}

///|
pub fn Profile::name(self : Profile) -> String {
  match self {
    Generic => "generic"
    DeepSeek => "deepseek"
    Kimi => "kimi"
    Qwen => "qwen"
    Glm => "glm"
  }
}

///|
/// Lint with the portable rules plus the rules of `profile`.
pub fn lint_with_profile(
  schema_text : StringView,
  profile : Profile,
) -> Array[Diagnostic] {
  let diags = lint(schema_text)
  if profile == Generic {
    return diags
  }
  let parsed = @json.parse(schema_text) catch { _ => return diags }
  guard parsed is Object(root) else { return diags }
  visit_schema(root, "$", true, fn(node, path, is_root) {
    check_descriptions(node, path, diags)
    match profile {
      DeepSeek => check_deepseek(node, path, diags)
      Kimi => check_kimi(node, path, is_root, diags)
      Qwen => check_qwen(node, path, diags)
      Glm => check_glm(node, path, diags)
      Generic => ()
    }
  })
  diags
}

///|
/// Pre-order walk over every sub-schema. `f` runs on a node before its
/// children are visited, so `f` may safely rewrite the node in place.
fn visit_schema(
  node : Map[String, Json],
  path : String,
  is_root : Bool,
  f : (Map[String, Json], String, Bool) -> Unit,
) -> Unit {
  f(node, path, is_root)
  for key in ["properties", "$defs", "definitions", "patternProperties"] {
    if node.get(key) is Some(Object(m)) {
      m.each(fn(name, value) {
        if value is Object(child) {
          visit_schema(child, "\{path}.\{key}.\{name}", false, f)
        }
      })
    }
  }
  for key in ["items", "additionalProperties", "not", "contains"] {
    if node.get(key) is Some(Object(child)) {
      visit_schema(child, "\{path}.\{key}", false, f)
    }
  }
  for key in ["anyOf", "oneOf", "allOf", "prefixItems", "items"] {
    if node.get(key) is Some(Array(arr)) {
      for i, item in arr {
        if item is Object(child) {
          visit_schema(child, "\{path}.\{key}[\{i}]", false, f)
        }
      }
    }
  }
}

///|
/// ASL010 (all provider profiles): tool-calling models pick argument values
/// from `description`; a property without one is a common cause of wrong
/// or hallucinated arguments.
fn check_descriptions(
  node : Map[String, Json],
  path : String,
  diags : Array[Diagnostic],
) -> Unit {
  guard node.get("properties") is Some(Object(props)) else { return }
  props.each(fn(name, value) {
    if value is Object(child) &&
      !child.contains("description") &&
      !child.contains("$ref") {
      diags.push({
        path: "\{path}.properties.\{name}",
        code: "ASL010",
        message: "property \"\{name}\" has no description; models rely on it to fill tool arguments",
        severity: Warning,
      })
    }
  })
}

///|
fn unsupported(
  node : Map[String, Json],
  path : String,
  keys : Array[String],
  code : String,
  provider : String,
  severity : Severity,
  diags : Array[Diagnostic],
) -> Unit {
  for key in keys {
    if node.contains(key) {
      diags.push({
        path: "\{path}.\{key}",
        code,
        message: "\"\{key}\" is not supported by \{provider}",
        severity,
      })
    }
  }
}

///|
let deepseek_unsupported : Array[String] = [
  "minLength", "maxLength", "minItems", "maxItems", "oneOf", "allOf", "not", "if",
  "then", "else", "prefixItems", "patternProperties", "uniqueItems",
]

///|
let deepseek_formats : Array[String] = [
  "email", "hostname", "ipv4", "ipv6", "uuid",
]

///|
/// DeepSeek function-calling `strict` mode (beta).
/// ASL101: keyword / type / format the server rejects.
/// ASL102: every object must list all properties in `required` and set
/// `additionalProperties: false`.
fn check_deepseek(
  node : Map[String, Json],
  path : String,
  diags : Array[Diagnostic],
) -> Unit {
  unsupported(
    node,
    path,
    deepseek_unsupported,
    "ASL101",
    "DeepSeek strict mode",
    Error,
    diags,
  )
  match node.get("format") {
    Some(String(f)) =>
      if !deepseek_formats.contains(f) {
        diags.push({
          path: "\{path}.format",
          code: "ASL101",
          message: "format \"\{f}\" is not supported by DeepSeek strict mode (only email, hostname, ipv4, ipv6, uuid)",
          severity: Error,
        })
      }
    _ => ()
  }
  match node.get("type") {
    Some(String("null")) | Some(Array(_)) =>
      diags.push({
        path: "\{path}.type",
        code: "ASL101",
        message: "DeepSeek strict mode supports only object/string/number/integer/boolean/array types (use anyOf instead of type arrays or null)",
        severity: Error,
      })
    _ => ()
  }
  guard node.get("type") is Some(String("object")) else { return }
  if !(node.get("additionalProperties") is Some(False)) {
    diags.push({
      path: "\{path}.additionalProperties",
      code: "ASL102",
      message: "DeepSeek strict mode requires additionalProperties: false on every object",
      severity: Error,
    })
  }
  let required = string_set(node.get("required"))
  if node.get("properties") is Some(Object(props)) {
    props.each(fn(name, _) {
      if !required.contains(name) {
        diags.push({
          path: "\{path}.properties.\{name}",
          code: "ASL102",
          message: "DeepSeek strict mode requires every property to be required; \"\{name}\" is optional",
          severity: Error,
        })
      }
    })
  }
}

///|
let kimi_unsupported : Array[String] = [
  "title", "$comment", "format", "prefixItems", "unevaluatedItems", "exclusiveMinimum",
  "exclusiveMaximum", "minContains", "maxContains", "$schema", "$id",
]

///|
/// Kimi / Moonshot MFJS (tools default to `strict: true`).
/// ASL111: keyword outside MFJS, nested $defs, external $ref, bad enum.
fn check_kimi(
  node : Map[String, Json],
  path : String,
  is_root : Bool,
  diags : Array[Diagnostic],
) -> Unit {
  let keys = if is_root {
    kimi_unsupported.filter(fn(k) { k != "$schema" && k != "$id" })
  } else {
    kimi_unsupported
  }
  unsupported(node, path, keys, "ASL111", "Kimi MFJS", Error, diags)
  if !is_root {
    for key in ["$defs", "definitions"] {
      if node.contains(key) {
        diags.push({
          path: "\{path}.\{key}",
          code: "ASL111",
          message: "Kimi MFJS only allows \{key} at the schema root",
          severity: Error,
        })
      }
    }
  }
  match node.get("$ref") {
    Some(String(r)) =>
      if !r.has_prefix("#") {
        diags.push({
          path: "\{path}.$ref",
          code: "ASL111",
          message: "Kimi MFJS only supports internal $ref (\"#\" or \"#/$defs/...\"), got \"\{r}\"",
          severity: Error,
        })
      }
    _ => ()
  }
  match node.get("enum") {
    Some(Array(values)) if !values.is_empty() => {
      let kinds : Map[String, Bool] = Map([])
      let mut bad = false
      for v in values {
        match v {
          String(_) => kinds.set("string", true)
          Number(_, ..) => kinds.set("number", true)
          _ => bad = true
        }
      }
      if bad || kinds.length() > 1 {
        diags.push({
          path: "\{path}.enum",
          code: "ASL111",
          message: "Kimi MFJS enum values must all be strings or all be numbers",
          severity: Error,
        })
      }
    }
    _ => ()
  }
}

///|
let qwen_unsupported : Array[String] = [
  "multipleOf", "uniqueItems", "contains", "minContains", "maxContains", "additionalItems",
  "patternProperties", "propertyNames",
]

///|
/// Qwen (Alibaba Cloud Bailian / DashScope) structured output strict mode.
/// ASL121: keyword that returns HTTP 400.
fn check_qwen(
  node : Map[String, Json],
  path : String,
  diags : Array[Diagnostic],
) -> Unit {
  unsupported(
    node,
    path,
    qwen_unsupported,
    "ASL121",
    "Qwen strict structured output (HTTP 400)",
    Error,
    diags,
  )
}

///|
let glm_undocumented : Array[String] = [
  "oneOf", "allOf", "not", "if", "then", "else", "patternProperties", "prefixItems",
  "$ref",
]

///|
/// Zhipu GLM: tools follow the OpenAI protocol but no schema subset or
/// strict mode is documented. ASL131 warns on keywords beyond the basic
/// type/properties/required/enum/anyOf shape shown in the official docs.
fn check_glm(
  node : Map[String, Json],
  path : String,
  diags : Array[Diagnostic],
) -> Unit {
  unsupported(
    node,
    path,
    glm_undocumented,
    "ASL131",
    "Zhipu GLM docs (undocumented, verify with a live call)",
    Warning,
    diags,
  )
}

///|
fn string_set(value : Json?) -> Map[String, Bool] {
  let set : Map[String, Bool] = Map([])
  if value is Some(Array(arr)) {
    for item in arr {
      if item is String(s) {
        set.set(s, true)
      }
    }
  }
  set
}
