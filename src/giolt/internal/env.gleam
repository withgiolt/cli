import gleam/bit_array
import gleam/int
import gleam/list
import gleam/regexp
import gleam/result
import gleam/string

pub type NameProblem {
  Malformed
  Reserved
}

pub type ValueProblem {
  TooLarge
  HasNul
  NotUnicode
}

pub type DevVars {
  DevVars(
    values: List(#(String, String)),
    missing: List(String),
    refused: List(#(String, ValueProblem)),
  )
}

pub const dotenv_path = ".env"

// The platform's rules (env_var.gleam in the giolt repo). Keep the two in
// step: a name this lets through is refused there after the upload, and a
// value `dev` accepts can't be set on the project.
pub const max_per_project = 64

const max_name_length = 64

const max_value_bytes = 5120

const reserved_prefix = "GIOLT_"

pub fn check_name(name: String) -> Result(String, NameProblem) {
  let assert Ok(pattern) = regexp.from_string("^[A-Z_][A-Z0-9_]*$")

  case
    regexp.check(pattern, name) && string.length(name) <= max_name_length,
    string.starts_with(name, reserved_prefix)
  {
    False, _ -> Error(Malformed)
    True, True -> Error(Reserved)
    True, False -> Ok(name)
  }
}

pub fn describe_problem(problem: NameProblem) -> String {
  case problem {
    Malformed ->
      "A variable name is upper case letters, digits and `_`, doesn't start "
      <> "with a digit, and is at most 64 characters."
    Reserved -> "Names starting with `GIOLT_` are kept for the platform."
  }
}

// A lone surrogate has no UTF-8 form, so the platform refuses it rather than
// store a different value.
pub fn check_value(value: String) -> Result(String, ValueProblem) {
  case
    has_lone_surrogate(value),
    bit_array.byte_size(bit_array.from_string(value)) > max_value_bytes,
    string.contains(value, "\u{0}")
  {
    True, _, _ -> Error(NotUnicode)
    False, True, _ -> Error(TooLarge)
    False, False, True -> Error(HasNul)
    False, False, False -> Ok(value)
  }
}

fn has_lone_surrogate(value: String) -> Bool {
  string.to_utf_codepoints(value)
  |> list.any(fn(codepoint) {
    let code = string.utf_codepoint_to_int(codepoint)
    code >= 0xD800 && code <= 0xDFFF
  })
}

pub fn describe_value_problem(problem: ValueProblem) -> String {
  case problem {
    TooLarge ->
      "is over " <> int.to_string(max_value_bytes) <> " bytes, Giolt's limit"
    HasNul -> "holds a NUL character, which Giolt refuses"
    NotUnicode -> "isn't valid Unicode text, which Giolt refuses"
  }
}

// Only declared names go into the platform object, as on a deploy. The shell
// wins over `.env`. A value the platform would refuse is left out too.
pub fn dev_vars(
  declared declared: List(String),
  shell shell: List(#(String, String)),
  dotenv dotenv: List(#(String, String)),
) -> DevVars {
  let found =
    list.filter_map(declared, fn(name) {
      case list.key_find(shell, name), list.key_find(dotenv, name) {
        Ok(value), _ | Error(Nil), Ok(value) -> Ok(#(name, value))
        Error(Nil), Error(Nil) -> Error(Nil)
      }
    })
  let missing =
    list.filter(declared, fn(name) { !result.is_ok(list.key_find(found, name)) })
  let #(values, refused) =
    list.fold(list.reverse(found), #([], []), fn(acc, var) {
      let #(values, refused) = acc
      let #(name, value) = var
      case check_value(value) {
        Ok(_) -> #([var, ..values], refused)
        Error(problem) -> #(values, [#(name, problem), ..refused])
      }
    })

  DevVars(values:, missing:, refused:)
}
