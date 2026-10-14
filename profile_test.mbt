///|
test "profile parse" {
  assert_true(
    @agent-schema-lint.Profile::parse("DeepSeek") ==
    Some(@agent-schema-lint.Profile::DeepSeek),
  )
  assert_true(
    @agent-schema-lint.Profile::parse("zhipu") ==
    Some(@agent-schema-lint.Profile::Glm),
  )
  assert_true(
    @agent-schema-lint.Profile::parse("bailian") ==
    Some(@agent-schema-lint.Profile::Qwen),
  )
  assert_true(@agent-schema-lint.Profile::parse("nope") == None)
}

///|
let strict_ok : String =
  #|{"type":"object","additionalProperties":false,
  #| "properties":{"city":{"type":"string","description":"城市"}},
  #| "required":["city"]}

///|
test "clean schema passes every profile" {
  for p in [@agent-schema-lint.Profile::Generic, DeepSeek, Kimi, Qwen, Glm] {
    assert_eq(
      @agent-schema-lint.lint_with_profile(strict_ok, p).length(),
      0,
      msg="profile \{p.name()}",
    )
  }
}

///|
test "deepseek rejects minLength, optional props and bad format" {
  let text =
    #|{"type":"object","additionalProperties":false,
    #| "properties":{
    #|   "q":{"type":"string","description":"x","minLength":1},
    #|   "d":{"type":"string","description":"x","format":"date"}},
    #| "required":["q"]}
  let diags = @agent-schema-lint.lint_with_profile(text, DeepSeek)
  let cs = codes(diags)
  assert_true(cs.contains("ASL101"))
  assert_true(cs.contains("ASL102"))
  assert_true(@agent-schema-lint.has_errors(diags))
  // generic only warns (ASL009)
  assert_false(@agent-schema-lint.has_errors(@agent-schema-lint.lint(text)))
}

///|
test "kimi rejects title, nested defs and mixed enum" {
  let text =
    #|{"type":"object","additionalProperties":false,"title":"T",
    #| "properties":{
    #|   "m":{"type":"string","description":"x","enum":["a",1]},
    #|   "n":{"type":"object","description":"x","additionalProperties":false,
    #|        "$defs":{"x":{"type":"string"}},
    #|        "properties":{"z":{"type":"string","description":"x"}},"required":["z"]}},
    #| "required":["m","n"]}
  let diags = @agent-schema-lint.lint_with_profile(text, Kimi)
  let paths = diags.filter(fn(d) { d.code == "ASL111" }).map(fn(d) { d.path })
  assert_eq(paths, ["$.title", "$.properties.m.enum", "$.properties.n.$defs"])
}

///|
test "qwen rejects uniqueItems and multipleOf" {
  let text =
    #|{"type":"object","additionalProperties":false,
    #| "properties":{
    #|   "tags":{"type":"array","description":"x","uniqueItems":true,"items":{"type":"string"}},
    #|   "n":{"type":"number","description":"x","multipleOf":5}},
    #| "required":["tags","n"]}
  let diags = @agent-schema-lint.lint_with_profile(text, Qwen)
  assert_eq(codes(diags), ["ASL121", "ASL121"])
}

///|
test "glm warns on oneOf, ASL010 on missing description" {
  let text =
    #|{"type":"object","additionalProperties":false,
    #| "properties":{"v":{"oneOf":[{"type":"string"},{"type":"integer"}]}},
    #| "required":["v"]}
  let diags = @agent-schema-lint.lint_with_profile(text, Glm)
  assert_eq(codes(diags), ["ASL010", "ASL131"])
  assert_false(@agent-schema-lint.has_errors(diags))
}
