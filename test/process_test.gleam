import giolt/internal/process
import gleam/javascript/promise
import gleam/string

pub fn output_returns_stdout_and_stderr_apart_test() {
  let script = "process.stdout.write('out'); process.stderr.write('err')"
  use result <- promise.map(
    process.output(".", process.runtime_path(), ["-e", script]),
  )

  assert result == Ok(#("out", "err"))
}

pub fn a_failed_command_reports_its_status_and_stderr_test() {
  let script = "process.stderr.write('broke\\n'); process.exit(3)"
  use result <- promise.map(
    process.output(".", process.runtime_path(), ["-e", script]),
  )

  let assert Error(message) = result
  assert string.contains(message, "exited with status 3")
  assert string.ends_with(message, "broke")
}

pub fn a_command_that_does_not_exist_is_an_error_test() {
  use result <- promise.map(process.output(".", "giolt-no-such-command", []))

  let assert Error(_) = result
}
