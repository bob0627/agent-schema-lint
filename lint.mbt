///|
/// Lint a JSON Schema document text.
/// Returns diagnostics (possibly empty). Parse failures become ASL001 errors.
pub fn lint(schema_text : StringView) -> Array[Diagnostic] {
  let diags : Array[Diagnostic] = []
  let parsed = @json.parse(schema_text) catch {
    err => {
      diags.push({
        path: "$",
        code: "ASL001",
        message: "invalid JSON: \{err}",
        severity: Error,
      })
      return diags
    }
  }
  match parsed {
    Object(root) => {
      lint_root(root, diags)
      let defs = collect_defs(root)
      walk_schema(root, "$", defs, diags, is_root=true)
    }
    _ =>
      diags.push({
        path: "$",
        code: "ASL001",
        message: "schema root must be a JSON object",
        severity: Error,
      })
  }
  diags
}

///|
fn lint_root(root : Map[String, Json], diags : Array[Diagnostic]) -> Unit {
  match root.get("type") {
    None =>
      diags.push({
        path: "$",
        code: "ASL002",
        message: "root schema should declare type: \"object\" for agent structured output",
        severity: Error,
      })
    Some(String("object")) => ()
    Some(other) =>
      diags.push({
        path: "$.type",
        code: "ASL002",
        message: "root type must be \"object\", got \{summarize_json(other)}",
        severity: Error,
      })
  }
}

///|
fn collect_defs(root : Map[String, Json]) -> Map[String, Bool] {
  let defs : Map[String, Bool] = Map([])
  collect_defs_from_key(root, "$defs", defs)
  collect_defs_from_key(root, "definitions", defs)
  defs
}

///|
fn collect_defs_from_key(
  root : Map[String, Json],
  key : String,
  defs : Map[String, Bool],
) -> Unit {
  match root.get(key) {
    Some(Object(m)) => m.each(fn(name, _) { defs.set(name, true) })
    _ => ()
  }
}

///|
fn walk_schema(
  node : Map[String, Json],
  path : String,
  defs : Map[String, Bool],
  diags : Array[Diagnostic],
  is_root? : Bool = false,
) -> Unit {
  check_missing_type(node, path, diags, is_root~)
  check_empty_properties(node, path, diags)
  check_empty_enum(node, path, diags)
  check_additional_properties(node, path, diags)
  check_required_unknown(node, path, diags)
  check_all_properties_required(node, path, diags)
  check_ref(node, path, defs, diags)

  // Recurse into properties
  match node.get("properties") {
    Some(Object(props)) =>
      props.each(fn(name, value) {
        match value {
          Object(child) =>
            walk_schema(child, "\{path}.properties.\{name}", defs, diags)
          _ => ()
        }
      })
    _ => ()
  }

  // Recurse into items (single schema)
  match node.get("items") {
    Some(Object(child)) => walk_schema(child, "\{path}.items", defs, diags)
    Some(Array(arr)) => {
      let mut i = 0
      for item in arr {
        match item {
          Object(child) =>
            walk_schema(child, "\{path}.items[\{i}]", defs, diags)
          _ => ()
        }
        i = i + 1
      }
    }
    _ => ()
  }

  // Recurse into additionalProperties if object schema
  match node.get("additionalProperties") {
    Some(Object(child)) =>
      walk_schema(child, "\{path}.additionalProperties", defs, diags)
    _ => ()
  }

  // Recurse into $defs / definitions
  for key in ["$defs", "definitions"] {
    match node.get(key) {
      Some(Object(m)) =>
        m.each(fn(name, value) {
          match value {
            Object(child) =>
              walk_schema(child, "\{path}.\{key}.\{name}", defs, diags)
            _ => ()
          }
        })
      _ => ()
    }
  }

  // anyOf / oneOf / allOf
  for key in ["anyOf", "oneOf", "allOf"] {
    match node.get(key) {
      Some(Array(arr)) => {
        let mut i = 0
        for item in arr {
          match item {
            Object(child) =>
              walk_schema(child, "\{path}.\{key}[\{i}]", defs, diags)
            _ => ()
          }
          i = i + 1
        }
      }
      _ => ()
    }
  }
}

///|
fn check_missing_type(
  node : Map[String, Json],
  path : String,
  diags : Array[Diagnostic],
  is_root~ : Bool,
) -> Unit {
  if is_root {
    // ASL002 already covers root type
    return
  }
  if node.contains("type") || node.contains("$ref") {
    return
  }
  // Heuristic: looks like a schema node if it has common keywords
  let schema_like = node.contains("properties") ||
    node.contains("items") ||
    node.contains("enum") ||
    node.contains("required") ||
    node.contains("additionalProperties")
  if schema_like {
    diags.push({
      path,
      code: "ASL003",
      message: "schema object is missing \"type\" (and is not a $ref)",
      severity: Error,
    })
  }
}

///|
fn check_empty_properties(
  node : Map[String, Json],
  path : String,
  diags : Array[Diagnostic],
) -> Unit {
  match node.get("properties") {
    Some(Object(props)) =>
      if props.is_empty() {
        diags.push({
          path: "\{path}.properties",
          code: "ASL004",
          message: "properties must not be an empty object",
          severity: Error,
        })
      }
    Some(_) =>
      diags.push({
        path: "\{path}.properties",
        code: "ASL004",
        message: "properties must be an object",
        severity: Error,
      })
    None => ()
  }
}

///|
fn check_empty_enum(
  node : Map[String, Json],
  path : String,
  diags : Array[Diagnostic],
) -> Unit {
  match node.get("enum") {
    Some(Array(arr)) =>
      if arr.is_empty() {
        diags.push({
          path: "\{path}.enum",
          code: "ASL005",
          message: "enum must not be empty",
          severity: Error,
        })
      }
    Some(_) =>
      diags.push({
        path: "\{path}.enum",
        code: "ASL005",
        message: "enum must be an array",
        severity: Error,
      })
    None => ()
  }
}

///|
fn check_additional_properties(
  node : Map[String, Json],
  path : String,
  diags : Array[Diagnostic],
) -> Unit {
  let is_object = match node.get("type") {
    Some(String("object")) => true
    _ => false
  }
  if !is_object {
    return
  }
  match node.get("additionalProperties") {
    Some(False) => ()
    Some(True) =>
      diags.push({
        path: "\{path}.additionalProperties",
        code: "ASL006",
        message: "additionalProperties: true is discouraged for strict agent schemas; prefer false",
        severity: Warning,
      })
    Some(_) =>
      // object schema as additionalProperties — allowed but warn for strict packs
      diags.push({
        path: "\{path}.additionalProperties",
        code: "ASL006",
        message: "non-false additionalProperties may break strict structured-output providers",
        severity: Warning,
      })
    None =>
      diags.push({
        path,
        code: "ASL006",
        message: "object type should set additionalProperties: false for strict agent schemas",
        severity: Warning,
      })
  }
}

///|
fn check_required_unknown(
  node : Map[String, Json],
  path : String,
  diags : Array[Diagnostic],
) -> Unit {
  let props : Map[String, Bool] = Map([])
  match node.get("properties") {
    Some(Object(m)) => m.each(fn(name, _) { props.set(name, true) })
    _ => ()
  }
  match node.get("required") {
    Some(Array(arr)) => {
      let mut i = 0
      for item in arr {
        match item {
          String(name) =>
            if !props.contains(name) {
              diags.push({
                path: "\{path}.required[\{i}]",
                code: "ASL007",
                message: "required field \"\{name}\" is not declared in properties",
                severity: Error,
              })
            }
          _ =>
            diags.push({
              path: "\{path}.required[\{i}]",
              code: "ASL007",
              message: "required entries must be strings",
              severity: Error,
            })
        }
        i = i + 1
      }
    }
    Some(_) =>
      diags.push({
        path: "\{path}.required",
        code: "ASL007",
        message: "required must be an array of strings",
        severity: Error,
      })
    None => ()
  }
}

///|
/// ASL009: strict structured-output modes require every declared property to
/// be listed in `required` (optional fields should be nullable instead).
fn check_all_properties_required(
  node : Map[String, Json],
  path : String,
  diags : Array[Diagnostic],
) -> Unit {
  guard node.get("properties") is Some(Object(props)) else { return }
  let required : Map[String, Bool] = Map([])
  match node.get("required") {
    Some(Array(arr)) =>
      for item in arr {
        if item is String(name) {
          required.set(name, true)
        }
      }
    None => ()
    // Non-array `required` is already an ASL007 error.
    Some(_) => return
  }
  props.each(fn(name, _) {
    if !required.contains(name) {
      diags.push({
        path: "\{path}.properties.\{name}",
        code: "ASL009",
        message: "property \"\{name}\" is not listed in required; strict structured-output modes require every property (make it nullable instead of optional)",
        severity: Warning,
      })
    }
  })
}

///|
fn check_ref(
  node : Map[String, Json],
  path : String,
  defs : Map[String, Bool],
  diags : Array[Diagnostic],
) -> Unit {
  match node.get("$ref") {
    Some(String(ref_str)) =>
      match local_def_name(ref_str) {
        Some(name) =>
          if !defs.contains(name) {
            diags.push({
              path: "\{path}.$ref",
              code: "ASL008",
              message: "dangling local $ref \"\{ref_str}\" (no matching $defs/definitions entry)",
              severity: Error,
            })
          }
        None => ()
      }
    Some(_) =>
      diags.push({
        path: "\{path}.$ref",
        code: "ASL008",
        message: "$ref must be a string",
        severity: Error,
      })
    None => ()
  }
}

///|
/// Extract local def name from `#/$defs/Name` or `#/definitions/Name`.
fn local_def_name(ref_str : String) -> String? {
  let prefixes = ["#/$defs/", "#/definitions/"]
  for prefix in prefixes {
    match ref_str.strip_prefix(prefix) {
      Some(rest) => {
        let name = rest.to_owned()
        // reject nested paths like foo/bar for v0 coarse check — still treat as name
        if name.length() > 0 && !name.contains("/") {
          return Some(name)
        } else {
          return None
        }
      }
      None => ()
    }
  }
  None
}

///|
fn summarize_json(value : Json) -> String {
  match value {
    Null => "null"
    True => "true"
    False => "false"
    Number(n, ..) => "\{n}"
    String(s) => "\"\{s}\""
    Array(_) => "array"
    Object(_) => "object"
  }
}
