import giolt/internal/afterglow
import gleam/list
import gleam/result
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
  let toml =
    afterglow.gleam_toml(package: "hello", project_path: "../../..", locked: [])

  assert string.contains(toml, "name = \"giolt_afterglow_build\"\n")
  assert string.contains(toml, "target = \"erlang\"\n")
  assert string.contains(toml, "hello = { path = \"../../..\" }\n")
  assert string.contains(toml, "afterglow = \">= 0.2.0 and < 1.0.0\"\n")
  assert string.contains(toml, "gleam_stdlib = \">= 1.0.0 and < 2.0.0\"\n")
}

pub fn build_package_pins_the_versions_the_user_locked_test() {
  let toml =
    afterglow.gleam_toml(package: "hello", project_path: "../../..", locked: [
      #("gleam_stdlib", "1.0.5"),
      #("wisp", "2.2.2"),
    ])

  assert string.contains(toml, "gleam_stdlib = \"== 1.0.5\"\n")
  assert string.contains(toml, "wisp = \"== 2.2.2\"\n")
  assert !string.contains(toml, "gleam_stdlib = \">=")
  assert string.contains(toml, "afterglow = \">= 0.2.0 and < 1.0.0\"\n")
}

const manifest =
  "# Do not manually edit this file, it is managed by Gleam.

packages = [
  { name = \"forked\", version = \"0.2.0\", build_tools = [\"gleam\"], requirements = [], source = \"git\", repo = \"https://example.com/forked\", commit = \"abc\" },
  { name = \"gleam_regexp\", version = \"1.0.0\", build_tools = [\"gleam\"], requirements = [\"gleam_stdlib\"], otp_app = \"gleam_regexp\", source = \"hex\", outer_checksum = \"A3655FDD\" },
  { name = \"gleam_stdlib\", version = \"1.0.5\", build_tools = [\"gleam\"], requirements = [], otp_app = \"gleam_stdlib\", source = \"hex\", outer_checksum = \"CEE5B6C0\" },
  { name = \"gleeunit\", version = \"1.11.0\", build_tools = [\"gleam\"], requirements = [\"gleam_stdlib\"], otp_app = \"gleeunit\", source = \"hex\", outer_checksum = \"EC31ABA7\" },
  { name = \"shared\", version = \"0.1.0\", build_tools = [\"gleam\"], requirements = [\"tom\"], source = \"local\", path = \"../shared\" },
  { name = \"tom\", version = \"2.1.0\", build_tools = [\"gleam\"], requirements = [\"gleam_stdlib\"], otp_app = \"tom\", source = \"hex\", outer_checksum = \"1A2B3C4D\" },
]

[requirements]
forked = { git = \"https://example.com/forked\", ref = \"abc\" }
gleam_regexp = { version = \">= 1.0.0 and < 2.0.0\" }
gleeunit = { version = \">= 1.0.0 and < 2.0.0\" }
shared = { path = \"../shared\" }
"

pub fn the_manifest_locks_only_hex_packages_test() {
  assert afterglow.locked_versions(manifest:, dependencies: ["gleam_regexp"])
    == Ok([#("gleam_regexp", "1.0.0"), #("gleam_stdlib", "1.0.5")])
}

pub fn dev_dependencies_are_not_pinned_test() {
  let assert Ok(locked) =
    afterglow.locked_versions(manifest:, dependencies: [
      "forked", "gleam_regexp",
    ])

  assert list.key_find(locked, "gleeunit") |> result.is_error
}

pub fn hex_packages_behind_a_path_dependency_are_pinned_test() {
  assert afterglow.locked_versions(manifest:, dependencies: ["shared"])
    == Ok([#("gleam_stdlib", "1.0.5"), #("tom", "2.1.0")])
}

pub fn a_manifest_written_with_crlf_still_reads_test() {
  assert afterglow.locked_versions(
      manifest: string.replace(manifest, "\n", "\r\n"),
      dependencies: ["gleam_regexp"],
    )
    == Ok([#("gleam_regexp", "1.0.0"), #("gleam_stdlib", "1.0.5")])
}

pub fn a_manifest_with_no_packages_locks_nothing_test() {
  assert afterglow.locked_versions(manifest: "packages = []\n", dependencies: [
      "wisp",
    ])
    == Ok([])
}

pub fn a_broken_manifest_is_an_error_test() {
  assert afterglow.locked_versions(manifest: "packages = [", dependencies: [])
    == Error(Nil)
  assert afterglow.locked_versions(
      manifest: "packages = [{ source = \"hex\" }]\n",
      dependencies: [],
    )
    == Error(Nil)
}

pub fn steps_are_numbered_in_order_test() {
  assert list.map(afterglow.steps, afterglow.step_number)
    == list.index_map(afterglow.steps, fn(_, index) { index + 1 })
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

  assert afterglow.warnings(output)
    == afterglow.Warnings(
      missing: ["crypto:mac/4", "gleam_httpc_ffi:send/1", "lists:nothing/9"],
      other: [],
    )
}

pub fn no_warnings_means_nothing_missing_test() {
  assert afterglow.warnings(
      "afterglow: 89 functions from 17 modules -> app.wasm (208904 bytes)\n",
    )
    == afterglow.Warnings(missing: [], other: [])
}

pub fn warnings_with_other_wording_are_passed_on_test() {
  let output =
    "warning: cannot read build/x.beam: denied
warning: NIF/BIF not implemented by afterglow_runtime: crypto:mac/4
warning: function not available: ets:new/2
"

  assert afterglow.warnings(output)
    == afterglow.Warnings(missing: ["crypto:mac/4"], other: [
      "cannot read build/x.beam: denied",
      "function not available: ets:new/2",
    ])
}

pub fn the_missing_note_lists_each_function_test() {
  let note = afterglow.describe_missing(["crypto:mac/4", "ets:new/2"])

  assert string.contains(note, "\n  - crypto:mac/4\n  - ets:new/2")
  assert string.contains(note, "500")
}

pub fn the_other_note_lists_each_warning_test() {
  assert afterglow.describe_other(["a", "b"])
    == "afterglow warned:\n  - a\n  - b"
}

pub fn otp_dirs_with_spaces_stay_whole_test() {
  assert afterglow.otp_ebin_dirs(
      "C:/Program Files/Erlang OTP/lib/stdlib-7.0\r\n",
    )
    == ["C:/Program Files/Erlang OTP/lib/stdlib-7.0/ebin"]
}

pub fn optimise_runs_o3_with_the_merge_features_test() {
  let args = afterglow.optimise_args(input: "m.wasm", out: "o.wasm")

  assert list.take(list.reverse(args), 4) == ["o.wasm", "-o", "m.wasm", "-O3"]
  assert list.contains(args, "--enable-tail-call")
  assert list.filter(args, string.starts_with(_, "--enable-"))
    == list.filter(
      afterglow.merge_args(runtime: "r", app: "a", out: "o"),
      string.starts_with(_, "--enable-"),
    )
}

pub fn binaryen_comes_from_its_versioned_npm_tarball_test() {
  assert afterglow.binaryen_tarball_url()
    == "https://registry.npmjs.org/binaryen/-/binaryen-"
    <> afterglow.binaryen_version
    <> ".tgz"
  assert afterglow.binaryen_dir()
    == "./build/dev/bin/binaryen-" <> afterglow.binaryen_version
  assert list.contains(afterglow.binaryen_files(), "bin/package.json")
}

// afterglow 0.2.0 ships its Worker entry as index.mjs, the name the platform
// wraps, next to the host.mjs it imports. 0.1.x shipped a single index.js.
pub fn the_worker_is_afterglows_entry_and_host_test() {
  assert afterglow.worker_files == ["index.mjs", "host.mjs"]
}

// The build package pins whatever afterglow the user's manifest locks, so a
// lock on an older afterglow would skip the minimum the CLI needs and fail
// later, copying files that release doesn't have.
pub fn a_locked_afterglow_older_than_0_2_is_refused_test() {
  let assert Error(message) =
    afterglow.check_locked_runtime([#("afterglow", "0.1.1"), #("wisp", "2.2.2")])
  assert string.contains(message, "0.1.1")
  assert string.contains(message, "gleam update afterglow")
}

pub fn a_locked_afterglow_from_1_0_is_refused_test() {
  let assert Error(_) =
    afterglow.check_locked_runtime([#("afterglow", "1.0.0")])
}

pub fn a_supported_or_absent_afterglow_lock_passes_test() {
  assert afterglow.check_locked_runtime([#("afterglow", "0.2.0")]) == Ok(Nil)
  assert afterglow.check_locked_runtime([#("afterglow", "0.13.4")]) == Ok(Nil)
  assert afterglow.check_locked_runtime([#("wisp", "2.2.2")]) == Ok(Nil)
}
