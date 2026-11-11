import giolt/internal/effect.{type Effect}

pub fn run(command: String, args: List(String)) -> Effect(Result(Nil, String)) {
  run_in(".", command, args)
}

@external(javascript, "./ffi_process.mjs", "run")
pub fn run_in(
  directory: String,
  command: String,
  args: List(String),
) -> Effect(Result(Nil, String))

@external(javascript, "./ffi_process.mjs", "output")
pub fn output(
  directory: String,
  command: String,
  args: List(String),
) -> Effect(Result(#(String, String), String))

@external(javascript, "./ffi_process.mjs", "runtime_path")
pub fn runtime_path() -> String

@external(javascript, "./ffi_process.mjs", "platform")
pub fn platform() -> String

@external(javascript, "./ffi_process.mjs", "shell")
pub fn shell(command: String) -> Effect(Result(Nil, String))

@external(javascript, "./ffi_process.mjs", "forever")
pub fn forever() -> Effect(Nil)

@external(javascript, "./ffi_process.mjs", "available")
pub fn available(command: String, args: List(String)) -> Bool

@external(javascript, "./ffi_process.mjs", "exit")
pub fn exit(code: Int) -> Nil

@external(javascript, "./ffi_process.mjs", "is_interactive")
pub fn is_interactive() -> Bool

@external(javascript, "./ffi_process.mjs", "read_line")
pub fn read_line(prompt: String) -> Effect(String)

@external(javascript, "./ffi_process.mjs", "sleep")
pub fn sleep(milliseconds: Int) -> Effect(Nil)

@external(javascript, "./ffi_process.mjs", "open_url")
pub fn open_url(url: String) -> Nil
