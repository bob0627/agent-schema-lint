// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "bob/agent-schema-lint"

version = "0.1.0"

readme = "README.mbt.md"

repository = ""

license = "Apache-2.0"

keywords = ["json-schema", "lint", "agent", "cli"]

preferred_target = "native"

description = "Static subset linter for LLM / Agent JSON Schema (structured output & tools)"

import {
  "moonbitlang/async@0.22.2",
}
