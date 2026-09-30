///|
/// Exit codes: 0 = no Error findings (warnings allowed), 1 = Error findings,
/// 2 = usage error or unreadable input.
extern "c" fn c_exit(code : Int) = "exit"

///|
fn cli() -> @argparse.Command {
  @argparse.Command(
    "agent-schema-lint",
    about="Lint JSON Schema documents for LLM / Agent structured-output subsets",
    version="0.1.0",
    options=[
      @argparse.OptionArg(
        "format",
        long="format",
        about="Output format: text or json",
        default_values=["text"],
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
  let text = @fs.read_file(file).text() catch {
    err => {
      @stdio.stderr.write("error: cannot read \{file}: \{err}\n")
      c_exit(2)
      return
    }
  }
  let diags = @lib.lint(text)
  let failed = @lib.has_errors(diags)
  if format == "json" {
    println(@lib.diagnostics_to_json(diags))
  } else if diags.is_empty() {
    println("ok: \{file}")
  } else {
    for d in diags {
      println(d.format())
    }
    if !failed {
      println("ok with warnings: \{file}")
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
