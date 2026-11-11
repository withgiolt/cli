import giolt/internal/effect.{type Effect}

// On Erlang, giolt's main only re-runs the CLI on JavaScript, so the rest of
// this module has no Erlang implementation.
pub const javascript_only =
  "giolt reached JavaScript-only code on Erlang. Run it with `gleam run --target javascript -m giolt`."

pub fn run(command: String, args: List(String)) -> Effect(Result(Nil, String)) {
  run_in(".", command, args)
}

@external(javascript, "./ffi_process.mjs", "on_javascript")
pub fn on_javascript() -> Bool {
  False
}

@external(erlang, "giolt_ffi_process", "run_attached")
pub fn run_attached(
  _command: String,
  _args: List(String),
) -> Result(Int, String) {
  panic as javascript_only
}

@external(javascript, "./ffi_process.mjs", "run")
pub fn run_in(
  _directory: String,
  _command: String,
  _args: List(String),
) -> Effect(Result(Nil, String)) {
  panic as javascript_only
}

@external(javascript, "./ffi_process.mjs", "output")
pub fn output(
  _directory: String,
  _command: String,
  _args: List(String),
) -> Effect(Result(#(String, String), String)) {
  panic as javascript_only
}

@external(javascript, "./ffi_process.mjs", "runtime_path")
pub fn runtime_path() -> String {
  panic as javascript_only
}

@external(javascript, "./ffi_process.mjs", "platform")
pub fn platform() -> String {
  panic as javascript_only
}

@external(javascript, "./ffi_process.mjs", "shell")
pub fn shell(_command: String) -> Effect(Result(Nil, String)) {
  panic as javascript_only
}

@external(javascript, "./ffi_process.mjs", "forever")
pub fn forever() -> Effect(Nil) {
  panic as javascript_only
}

@external(erlang, "giolt_ffi_process", "available")
@external(javascript, "./ffi_process.mjs", "available")
pub fn available(_command: String, _args: List(String)) -> Bool

@external(erlang, "giolt_ffi_process", "exit")
@external(javascript, "./ffi_process.mjs", "exit")
pub fn exit(code: Int) -> Nil

@external(javascript, "./ffi_process.mjs", "is_interactive")
pub fn is_interactive() -> Bool {
  panic as javascript_only
}

@external(javascript, "./ffi_process.mjs", "read_line")
pub fn read_line(_prompt: String) -> Effect(String) {
  panic as javascript_only
}

@external(javascript, "./ffi_process.mjs", "sleep")
pub fn sleep(_milliseconds: Int) -> Effect(Nil) {
  panic as javascript_only
}

@external(javascript, "./ffi_process.mjs", "open_url")
pub fn open_url(_url: String) -> Nil {
  panic as javascript_only
}
