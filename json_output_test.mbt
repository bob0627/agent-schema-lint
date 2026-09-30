///|
test "json: empty diagnostics render as empty array" {
  assert_eq(@agent-schema-lint.diagnostics_to_json([]), "[]")
}

///|
test "json: single diagnostic has path, code, message, severity" {
  let d : @agent-schema-lint.Diagnostic = {
    path: "$.properties",
    code: "ASL004",
    message: "properties must not be an empty object",
    severity: @agent-schema-lint.Error,
  }
  assert_eq(
    @agent-schema-lint.diagnostics_to_json([d]),
    "[{\"path\":\"$.properties\",\"code\":\"ASL004\",\"message\":\"properties must not be an empty object\",\"severity\":\"error\"}]",
  )
}

///|
test "json: warning severity and quote escaping" {
  let d : @agent-schema-lint.Diagnostic = {
    path: "$",
    code: "ASL006",
    message: "say \"false\"",
    severity: @agent-schema-lint.Warning,
  }
  assert_eq(
    @agent-schema-lint.diagnostics_to_json([d]),
    "[{\"path\":\"$\",\"code\":\"ASL006\",\"message\":\"say \\\"false\\\"\",\"severity\":\"warning\"}]",
  )
}

///|
test "json: output of lint round-trips through the JSON parser" {
  let text =
    #|{
    #|  "type": "object",
    #|  "additionalProperties": false,
    #|  "properties": { "a": { "type": "integer" } },
    #|  "required": ["a", "missing"]
    #|}
  let diags = @agent-schema-lint.lint(text)
  let parsed = @json.parse(@agent-schema-lint.diagnostics_to_json(diags))
  guard parsed is Array(items) else { fail("expected a JSON array") }
  assert_eq(items.length(), diags.length())
  guard items[0] is Object(first) else { fail("expected a JSON object") }
  assert_eq(first.get("code"), Some(Json::string("ASL007")))
  assert_eq(first.get("path"), Some(Json::string("$.required[1]")))
  assert_eq(first.get("severity"), Some(Json::string("error")))
}

///|
test "severity labels match text format" {
  assert_eq(@agent-schema-lint.Error.label(), "error")
  assert_eq(@agent-schema-lint.Warning.label(), "warning")
  let d : @agent-schema-lint.Diagnostic = {
    path: "$.x",
    code: "ASL006",
    message: "m",
    severity: @agent-schema-lint.Warning,
  }
  assert_eq(d.format(), "warning[ASL006] $.x: m")
}
