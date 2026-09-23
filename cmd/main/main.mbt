///|
async fn main {
  let matches = @argparse.Command(
    "agent-schema-lint",
    about="Lint JSON Schema documents for LLM / Agent structured-output subsets",
    version="0.1.0",
    positionals=[
      @argparse.PositionArg(
        "file",
        about="JSON Schema file to lint",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  ).parse()
  let file = match matches.values {
    { "file": [path], .. } => path
    _ => fail("missing file argument")
  }
  let text = @fs.read_file(file).text()
  let diags = @lib.lint(text)
  if diags.is_empty() {
    println("ok: \{file}")
  } else {
    for d in diags {
      println(d.format())
    }
    let n = diags.length()
    if @lib.has_errors(diags) {
      fail("lint failed: \{n} finding(s) in \{file}")
    } else {
      println("ok with warnings: \{file}")
    }
  }
}
