///|
/// Exit codes: 0 = no Error findings (warnings allowed), 1 = Error findings,
/// 2 = usage error or unreadable input.
extern "c" fn c_exit(code : Int) = "exit"

///|
/// All output goes through async stdio (unbuffered, in call order) so that
/// findings on stdout and the summary on stderr interleave correctly in pipes.
async fn out(line : String) -> Unit {
  @stdio.stdout.write("\{line}\n")
}

///|
fn cli() -> @argparse.Command {
  @argparse.Command(
    "agent-schema-lint",
    about="Lint JSON Schema documents for LLM / Agent structured-output subsets",
    version="0.2.0",
    flags=[
      @argparse.FlagArg(
        "fix",
        long="fix",
        about="Apply deterministic fixes and print the fixed schema",
      ),
      @argparse.FlagArg(
        "ai",
        long="ai",
        about="With --fix: let an OpenAI-compatible model (ASL_AI_API_KEY, ASL_AI_BASE_URL, ASL_AI_MODEL) rewrite the schema, then re-lint",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "output",
        short='o',
        long="output",
        about="With --fix: write the fixed schema to FILE instead of stdout",
      ),
      @argparse.OptionArg(
        "format",
        long="format",
        about="Output format: text or json",
        default_values=["text"],
      ),
      @argparse.OptionArg(
        "profile",
        long="profile",
        about="Provider profile: generic, deepseek, kimi, qwen, glm",
        default_values=["generic"],
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "file",
        about="JSON Schema file to lint",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  )
}

///|
async fn fail_usage(message : String) -> Unit {
  @stdio.stderr.write("error: \{message}\n\n\{cli().render_help()}\n")
  c_exit(2)
}

///|
async fn main {
  let matches = cli().parse() catch {
    err => {
      @stdio.stderr.write("\{err}\n")
      c_exit(2)
      return
    }
  }
  let file = match matches.values {
    { "file": [path], .. } => path
    _ => {
      fail_usage("missing file argument")
      return
    }
  }
  let format = match matches.values {
    { "format": [f], .. } => f
    _ => "text"
  }
  if format != "text" && format != "json" {
    fail_usage("unknown --format \"\{format}\" (expected text or json)")
    return
  }
  let profile_name = match matches.values {
    { "profile": [p], .. } => p
    _ => "generic"
  }
  guard @lib.Profile::parse(profile_name) is Some(profile) else {
    fail_usage(
      "unknown --profile \"\{profile_name}\" (expected generic, deepseek, kimi, qwen or glm)",
    )
    return
  }
  let text = @fs.read_file(file).text() catch {
    err => {
      @stdio.stderr.write("error: cannot read \{file}: \{err}\n")
      c_exit(2)
      return
    }
  }
  if matches.flags.get("fix") is Some(true) {
    let output = match matches.values {
      { "output": [o], .. } => Some(o)
      _ => None
    }
    run_fix(file, text, profile, matches.flags.get("ai") is Some(true), output)
    return
  }
  let diags = @lib.lint_with_profile(text, profile)
  let failed = @lib.has_errors(diags)
  if format == "json" {
    out(@lib.diagnostics_to_json(diags))
  } else if diags.is_empty() {
    out("ok: \{file}")
  } else {
    for d in diags {
      out(d.format())
    }
    if !failed {
      out("ok with warnings: \{file}")
    }
  }
  if failed {
    if format == "text" {
      @stdio.stderr.write(
        "lint failed: \{diags.length()} finding(s) in \{file}\n",
      )
    }
    c_exit(1)
  }
}

///|
fn env_or(names : Array[String], default : String) -> String {
  for n in names {
    if @env.get_env_var(n) is Some(v) && v != "" {
      return v
    }
  }
  default
}

///|
async fn log(line : String) -> Unit {
  @stdio.stderr.write("\{line}\n")
}

///|
fn summary(diags : Array[@lib.Diagnostic]) -> String {
  let (e, w) = @lib.count_findings(diags)
  "\{e} error / \{w} warning"
}

///|
/// `--fix`: deterministic fixes, then (with `--ai` and a key) an AI rewrite
/// that is kept only if re-linting shows it is strictly better.
async fn run_fix(
  file : String,
  text : String,
  profile : @lib.Profile,
  use_ai : Bool,
  output : String?,
) -> Unit {
  let before = @lib.lint_with_profile(text, profile)
  guard @lib.fix_schema(text, profile) is Some(result) else {
    log("error: \{file} is not a JSON object; nothing to fix")
    c_exit(2)
    return
  }
  let mut fixed = result.fixed
  let mut after = @lib.lint_with_profile(fixed, profile)
  log("[1/3] 修复前 (\{profile.name()}): \{summary(before)}")
  for c in result.changes {
    log("  fix  \{c}")
  }
  log("[2/3] 确定性修复后: \{summary(after)}")
  if use_ai {
    let key = env_or(["ASL_AI_API_KEY", "DEEPSEEK_API_KEY"], "")
    if key == "" {
      log(
        "[3/3] 跳过 AI：未设置 ASL_AI_API_KEY（离线模式，仅使用确定性修复）",
      )
    } else if after.is_empty() {
      log("[3/3] 已无问题，无需调用 AI")
    } else {
      let base = env_or(["ASL_AI_BASE_URL"], "https://api.deepseek.com")
      let model = env_or(["ASL_AI_MODEL"], "deepseek-flash")
      log("[3/3] 调用 AI 修复: \{base} model=\{model}")
      let body = @lib.ai_fix_request(fixed, after, profile, model)
      match ai_call(base, key, body.stringify()) {
        None => ()
        Some(raw) =>
          match @lib.ai_fix_extract(raw) {
            None =>
              log(
                "  AI 回答不是合法 JSON Schema（保留确定性结果）",
              )
            Some(candidate) => {
              let ai_diags = @lib.lint_with_profile(candidate, profile)
              if @lib.ai_fix_is_better(after, ai_diags) {
                log("  AI 修复后: \{summary(ai_diags)}（已采用）")
                fixed = candidate
                after = ai_diags
              } else {
                log(
                  "  AI 修复后: \{summary(ai_diags)}，没有更好（已丢弃）",
                )
              }
            }
          }
      }
    }
  }
  for d in after {
    log("  left \{d.format()}")
  }
  match output {
    Some(path) => {
      @fs.write_file(path, fixed, create_mode=CreateOrTruncate)
      log("已写入 \{path}")
    }
    None => out(fixed)
  }
  if @lib.has_errors(after) {
    c_exit(1)
  }
}

///|
/// POST to `{base}/chat/completions`; returns the body on HTTP 200, logs
/// and returns `None` otherwise (the caller keeps the offline result).
async fn ai_call(base : String, key : String, body : String) -> String? {
  let (r, data) = @http.post("\{base}/chat/completions", body, headers={
    "Authorization": "Bearer \{key}",
    "Content-Type": "application/json",
  }) catch {
    err => {
      log("  AI 请求失败（保留确定性结果）: \{err}")
      return None
    }
  }
  let raw = data.text() catch { _ => "" }
  if r.code != 200 {
    log("  AI 返回 HTTP \{r.code}（保留确定性结果）")
    return None
  }
  Some(raw)
}
