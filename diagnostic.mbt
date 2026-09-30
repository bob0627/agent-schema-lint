///|
/// Severity of a lint finding.
pub(all) enum Severity {
  Error
  Warning
} derive(Eq)

///|
pub extend Severity with Eq::{equal, not_equal}

///|
/// A single lint diagnostic.
pub(all) struct Diagnostic {
  path : String
  code : String
  message : String
  severity : Severity
} derive(Eq)

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
/// Lowercase label used in both text and JSON output: `"error"` / `"warning"`.
pub fn Severity::label(self : Severity) -> String {
  match self {
    Error => "error"
    Warning => "warning"
  }
}

///|
pub impl ToJson for Severity with fn to_json(self) {
  Json::string(self.label())
}

///|
pub extend Severity with ToJson::{to_json}

///|
pub fn Diagnostic::format(self : Diagnostic) -> String {
  "\{self.severity.label()}[\{self.code}] \{self.path}: \{self.message}"
}

///|
/// JSON object `{"path", "code", "message", "severity"}` (keys in that order).
pub impl ToJson for Diagnostic with fn to_json(self) {
  {
    "path": self.path.to_json(),
    "code": self.code.to_json(),
    "message": self.message.to_json(),
    "severity": self.severity.to_json(),
  }
}

///|
pub extend Diagnostic with ToJson::{to_json}

///|
/// Render diagnostics as a compact JSON array, e.g. for CI tools.
/// An empty input yields `[]`.
pub fn diagnostics_to_json(diags : ArrayView[Diagnostic]) -> String {
  diags.to_json().stringify()
}

///|
pub fn format_diagnostics(diags : ArrayView[Diagnostic]) -> String {
  let buf = StringBuilder()
  for d in diags {
    buf.write_string(d.format())
    buf.write_string("\n")
  }
  buf.to_string()
}

///|
pub fn has_errors(diags : ArrayView[Diagnostic]) -> Bool {
  for d in diags {
    if d.severity == Error {
      return true
    }
  }
  false
}
