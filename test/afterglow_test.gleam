import giolt/internal/afterglow
import gleam/string

pub fn start_calls_handle_through_a_lambda_test() {
  let source = afterglow.start_source("hello")

  assert string.contains(
    source,
    "afterglow.serve(fn(req) { user.handle(req) })",
  )
  assert !string.contains(source, "afterglow.serve(user.handle)")
}

pub fn start_is_a_zero_argument_function_test() {
  assert string.contains(afterglow.start_source("hello"), "pub fn start() {")
}

pub fn start_imports_the_entry_module_under_a_fixed_alias_test() {
  assert string.contains(
    afterglow.start_source("hello"),
    "import hello as user\n",
  )
  assert string.contains(
    afterglow.start_source("my_app/server"),
    "import my_app/server as user\n",
  )
}

pub fn build_package_depends_on_the_project_and_the_runtime_test() {
  let toml = afterglow.gleam_toml(package: "hello", project_path: "../../..")

  assert string.contains(toml, "name = \"giolt_afterglow_build\"\n")
  assert string.contains(toml, "target = \"erlang\"\n")
  assert string.contains(toml, "hello = { path = \"../../..\" }\n")
  assert string.contains(toml, "afterglow = \">= 0.1.0 and < 1.0.0\"\n")
}

pub fn compiler_names_match_the_hex_package_test() {
  assert afterglow.compiler_name("linux-x64") == Ok("afterglow-linux-x64")
  assert afterglow.compiler_name("linux-arm64") == Ok("afterglow-linux-arm64")
  assert afterglow.compiler_name("darwin-x64") == Ok("afterglow-darwin-x64")
  assert afterglow.compiler_name("darwin-arm64") == Ok("afterglow-darwin-arm64")
  assert afterglow.compiler_name("win32-x64") == Ok("afterglow-win32-x64.exe")
}

pub fn unsupported_platforms_name_the_ones_that_work_test() {
  let assert Error(message) = afterglow.compiler_name("win32-arm64")

  assert string.contains(message, "win32-arm64")
  assert string.contains(message, "Windows (x64)")
}

pub fn otp_dirs_become_ebin_dirs_test() {
  let output =
    "/usr/lib/erlang/lib/stdlib-7.0\r\n/usr/lib/erlang/lib/kernel-10.3\n/usr/lib/erlang/lib/erts-16.0\n"

  assert afterglow.otp_ebin_dirs(output)
    == [
      "/usr/lib/erlang/lib/stdlib-7.0/ebin",
      "/usr/lib/erlang/lib/kernel-10.3/ebin",
      "/usr/lib/erlang/lib/erts-16.0/ebin",
    ]
}

pub fn compile_starts_at_the_generated_start_module_test() {
  assert afterglow.compile_args(
      runtime: "rt.wasm",
      beam_dirs: ["a/ebin", "b/ebin"],
      out: "app.wasm",
    )
    == [
      "build", "-v", "--rt", "rt.wasm", "--entry",
      "giolt_afterglow_start:start/0", "-o", "app.wasm", "--beams", "a/ebin",
      "--beams", "b/ebin",
    ]
}

pub fn merge_names_the_runtime_module_the_app_imports_test() {
  let args =
    afterglow.merge_args(runtime: "rt.wasm", app: "a.wasm", out: "m.wasm")

  assert string.contains(
    string.join(args, " "),
    "rt.wasm afterglow_runtime a.wasm app -o m.wasm",
  )
  assert string.contains(string.join(args, " "), "--enable-tail-call")
}

pub fn missing_functions_come_from_the_compiler_warnings_test() {
  let output =
    "warning: NIF/BIF not implemented by afterglow_runtime: crypto:mac/4\r
warning: no module for gleam_httpc_ffi:send/1
warning: undefined function: lists:nothing/9
warning: NIF/BIF not implemented by afterglow_runtime: crypto:mac/4
afterglow: 89 functions from 17 modules -> app.wasm (208904 bytes)
"

  assert afterglow.missing_functions(output)
    == ["crypto:mac/4", "gleam_httpc_ffi:send/1", "lists:nothing/9"]
}

pub fn no_warnings_means_nothing_missing_test() {
  assert afterglow.missing_functions(
      "afterglow: 89 functions from 17 modules -> app.wasm (208904 bytes)\n",
    )
    == []
}

pub fn the_missing_note_lists_each_function_test() {
  let note = afterglow.describe_missing(["crypto:mac/4", "ets:new/2"])

  assert string.contains(note, "\n  - crypto:mac/4\n  - ets:new/2")
  assert string.contains(note, "500")
}
