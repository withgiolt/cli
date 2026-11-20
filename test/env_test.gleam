import giolt/internal/env.{DevVars}
import gleam/string

pub fn dev_hands_the_app_only_declared_names_test() {
  assert env.dev_vars(
      declared: ["API_KEY"],
      shell: [#("PATH", "/bin")],
      dotenv: [#("API_KEY", "from-file"), #("OTHER", "x")],
    )
    == DevVars(values: [#("API_KEY", "from-file")], missing: [], refused: [])
}

pub fn the_shell_wins_over_dotenv_test() {
  assert env.dev_vars(
      declared: ["API_KEY"],
      shell: [#("API_KEY", "from-shell")],
      dotenv: [#("API_KEY", "from-file")],
    )
    == DevVars(values: [#("API_KEY", "from-shell")], missing: [], refused: [])
}

pub fn an_unset_declared_name_is_missing_test() {
  assert env.dev_vars(declared: ["API_KEY", "DATABASE_URL"], shell: [], dotenv: [
      #("DATABASE_URL", "postgres://"),
    ])
    == DevVars(
      values: [#("DATABASE_URL", "postgres://")],
      missing: ["API_KEY"],
      refused: [],
    )
}

pub fn an_empty_value_counts_as_set_test() {
  assert env.dev_vars(declared: ["FLAG"], shell: [], dotenv: [#("FLAG", "")])
    == DevVars(values: [#("FLAG", "")], missing: [], refused: [])
}

pub fn each_name_problem_is_described_test() {
  assert env.check_name("API_KEY") == Ok("API_KEY")
  assert env.check_name("api_key") == Error(env.Malformed)
  assert env.check_name("GIOLT_X") == Error(env.Reserved)
}

pub fn dev_leaves_out_a_value_the_platform_refuses_test() {
  let big = string.repeat("a", 5121)

  assert env.dev_vars(declared: ["BIG", "NUL", "OK"], shell: [], dotenv: [
      #("BIG", big),
      #("NUL", "a\u{0}b"),
      #("OK", "fine"),
    ])
    == DevVars(values: [#("OK", "fine")], missing: [], refused: [
      #("BIG", env.TooLarge),
      #("NUL", env.HasNul),
    ])
}

pub fn a_value_at_the_byte_limit_is_accepted_test() {
  let at_limit = string.repeat("é", 2560)

  assert env.check_value(at_limit) == Ok(at_limit)
  assert env.check_value(at_limit <> "a") == Error(env.TooLarge)
}
