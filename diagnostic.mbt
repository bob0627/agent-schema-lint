///|
/// Severity of a lint finding.
pub(all) enum Severity {
  Error
  Warning
} derive(Eq)

///|
pub extend Severity with Eq::{ equal, not_equal }

///|
/// A single lint diagnostic.
pub(all) struct Diagnostic {
  path : String
  code : String
  message : String
  severity : Severity
} derive(Eq)

///|
pub extend Diagnostic with Eq::{ equal, not_equal }

///|
pub fn Diagnostic::format(self : Diagnostic) -> String {
  let sev = match self.severity {
    Error => "error"
    Warning => "warning"
  }
  "\{sev}[\{self.code}] \{self.path}: \{self.message}"
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
