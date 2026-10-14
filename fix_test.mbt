///|
test "fix makes a loose schema pass deepseek strict mode" {
  let text =
    #|{"properties":{
    #|  "q":{"type":"string","description":"关键词","minLength":1},
    #|  "when":{"type":"string","description":"日期","format":"date"}},
    #| "required":["q","ghost"]}
  let before = @agent-schema-lint.lint_with_profile(text, DeepSeek)
  assert_true(@agent-schema-lint.has_errors(before))
  guard @agent-schema-lint.fix_schema(text, DeepSeek) is Some(r) else {
    fail("expected fix result")
  }
  let after = @agent-schema-lint.lint_with_profile(r.fixed, DeepSeek)
  assert_eq(after.length(), 0)
  assert_true(r.fixed.contains("（minLength: 1）"))
  assert_true(r.fixed.contains("（format: date）"))
  assert_false(r.fixed.contains("ghost"))
}

///|
test "fix is idempotent" {
  let text =
    #|{"type":"object","properties":{"a":{"type":"string","description":"x"}}}
  guard @agent-schema-lint.fix_schema(text, Kimi) is Some(r1) else {
    fail("fix1")
  }
  guard @agent-schema-lint.fix_schema(r1.fixed, Kimi) is Some(r2) else {
    fail("fix2")
  }
  assert_eq(r2.fixed, r1.fixed)
  assert_eq(r2.changes.length(), 0)
}

///|
test "fix refuses non-object input" {
  assert_true(@agent-schema-lint.fix_schema("[1]", Generic) is None)
  assert_true(@agent-schema-lint.fix_schema("{bad", Generic) is None)
}

///|
test "ai_fix_extract handles fenced answer and rejects junk" {
  let resp =
    #|{"choices":[{"message":{"role":"assistant","content":"```json\n{\"type\":\"object\"}\n```"}}]}
  assert_eq(
    @agent-schema-lint.ai_fix_extract(resp),
    Some(
      (
        #|{
        #|  "type": "object"
        #|}
      ),
    ),
  )
  assert_eq(
    @agent-schema-lint.ai_fix_extract(
      (
        #|{"choices":[{"message":{"content":"sorry"}}]}
      ),
    ),
    None,
  )
  assert_eq(@agent-schema-lint.ai_fix_extract("not json"), None)
}

///|
test "ai_fix_request carries profile and findings" {
  let diags = @agent-schema-lint.lint_with_profile(
    (
      #|{"type":"object","additionalProperties":false,"properties":{"a":{"type":"string"}},"required":["a"]}
    ),
    Qwen,
  )
  let body = @agent-schema-lint.ai_fix_request("{}", diags, Qwen, "qwen-plus").stringify()
  assert_true(body.contains("\"model\":\"qwen-plus\""))
  assert_true(body.contains("profile: qwen"))
  assert_true(body.contains("ASL010"))
}

///|
test "ai result accepted only when strictly better" {
  let w : @agent-schema-lint.Diagnostic = {
    path: "$",
    code: "ASL010",
    message: "m",
    severity: Warning,
  }
  let e : @agent-schema-lint.Diagnostic = { ..w, severity: Error, }
  assert_true(@agent-schema-lint.ai_fix_is_better([w], []))
  assert_false(@agent-schema-lint.ai_fix_is_better([w], [w]))
  assert_false(@agent-schema-lint.ai_fix_is_better([w], [e]))
}

///|
test "deepseek fix drops pydantic null branch" {
  let text =
    #|{"type":"object","properties":{"c":{"anyOf":[{"type":"string"},{"type":"null"}],"default":null,"title":"C"}},"required":[]}
  guard @agent-schema-lint.fix_schema(text, DeepSeek) is Some(r) else {
    fail("fix")
  }
  assert_eq(@agent-schema-lint.lint_with_profile(r.fixed, DeepSeek).length(), 0)
  assert_false(r.fixed.contains("null"))
}
