///|
fn codes(diags : Array[@agent-schema-lint.Diagnostic]) -> Array[String] {
  let out : Array[String] = []
  for d in diags {
    out.push(d.code)
  }
  out
}

///|
test "pass: minimal strict object" {
  let text =
    #|{
    #|  "type": "object",
    #|  "additionalProperties": false,
    #|  "properties": {
    #|    "name": { "type": "string" }
    #|  },
    #|  "required": ["name"]
    #|}
  let diags = @agent-schema-lint.lint(text)
  assert_eq(diags.length(), 0)
}

///|
test "fail: invalid json" {
  let diags = @agent-schema-lint.lint("{not-json")
  assert_true(codes(diags).contains("ASL001"))
  assert_true(@agent-schema-lint.has_errors(diags))
}

///|
test "fail: root not object type" {
  let text =
    #|{
    #|  "type": "string"
    #|}
  let diags = @agent-schema-lint.lint(text)
  assert_true(codes(diags).contains("ASL002"))
}

///|
test "fail: empty properties" {
  let text =
    #|{
    #|  "type": "object",
    #|  "additionalProperties": false,
    #|  "properties": {}
    #|}
  let diags = @agent-schema-lint.lint(text)
  assert_true(codes(diags).contains("ASL004"))
}

///|
test "fail: empty enum" {
  let text =
    #|{
    #|  "type": "object",
    #|  "additionalProperties": false,
    #|  "properties": {
    #|    "color": { "type": "string", "enum": [] }
    #|  },
    #|  "required": ["color"]
    #|}
  let diags = @agent-schema-lint.lint(text)
  assert_true(codes(diags).contains("ASL005"))
}

///|
test "fail: required unknown field" {
  let text =
    #|{
    #|  "type": "object",
    #|  "additionalProperties": false,
    #|  "properties": {
    #|    "a": { "type": "integer" }
    #|  },
    #|  "required": ["a", "missing"]
    #|}
  let diags = @agent-schema-lint.lint(text)
  assert_true(codes(diags).contains("ASL007"))
}

///|
test "fail: dangling local ref" {
  let text =
    #|{
    #|  "type": "object",
    #|  "additionalProperties": false,
    #|  "properties": {
    #|    "item": { "$ref": "#/$defs/Item" }
    #|  },
    #|  "required": ["item"],
    #|  "$defs": {
    #|    "Other": { "type": "string" }
    #|  }
    #|}
  let diags = @agent-schema-lint.lint(text)
  assert_true(codes(diags).contains("ASL008"))
}

///|
test "pass: valid local ref" {
  let text =
    #|{
    #|  "type": "object",
    #|  "additionalProperties": false,
    #|  "properties": {
    #|    "item": { "$ref": "#/$defs/Item" }
    #|  },
    #|  "required": ["item"],
    #|  "$defs": {
    #|    "Item": { "type": "string" }
    #|  }
    #|}
  let diags = @agent-schema-lint.lint(text)
  assert_eq(diags.length(), 0)
}

///|
test "warn: missing additionalProperties" {
  let text =
    #|{
    #|  "type": "object",
    #|  "properties": {
    #|    "x": { "type": "boolean" }
    #|  },
    #|  "required": ["x"]
    #|}
  let diags = @agent-schema-lint.lint(text)
  assert_true(codes(diags).contains("ASL006"))
  assert_false(@agent-schema-lint.has_errors(diags))
}

///|
test "fail: missing nested type" {
  let text =
    #|{
    #|  "type": "object",
    #|  "additionalProperties": false,
    #|  "properties": {
    #|    "nested": { "properties": { "y": { "type": "number" } } }
    #|  },
    #|  "required": ["nested"]
    #|}
  let diags = @agent-schema-lint.lint(text)
  assert_true(codes(diags).contains("ASL003"))
}

///|
test "format diagnostics" {
  let d : @agent-schema-lint.Diagnostic = {
    path: "$.x",
    code: "ASL004",
    message: "boom",
    severity: @agent-schema-lint.Error,
  }
  let s = d.format()
  assert_true(s.contains("ASL004"))
  assert_true(s.contains("$.x"))
}
