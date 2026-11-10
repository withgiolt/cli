import gleam/list
import gleam/string

pub const package_name = "giolt_afterglow_build"

pub const build_dir = "./build/.giolt/afterglow"

pub const start_module = "giolt_afterglow_start"

const runtime_range = ">= 0.1.0 and < 1.0.0"

/// Where Gleam unpacks the afterglow Hex package's compilers, runtime and Worker
/// entry inside the generated build package.
pub fn priv_dir() -> String {
  build_dir <> "/build/packages/afterglow/priv"
}

/// The files `giolt build` writes to `outdir`.
pub fn output_files() -> List(String) {
  ["app.wasm", "index.js"]
}

pub fn gleam_toml(
  package package: String,
  project_path project_path: String,
) -> String {
  "name = \"" <> package_name <> "\"
version = \"0.0.0\"
target = \"erlang\"

[dependencies]
gleam_stdlib = \">= 1.0.0 and < 2.0.0\"
afterglow = \"" <> runtime_range <> "\"
" <> package <> " = { path = \"" <> project_path <> "\" }
"
}

pub fn start_source(entry: String) -> String {
  "import afterglow
import " <> entry <> " as user

pub fn start() {
  afterglow.serve(fn(req) { user.handle(req) })
}
"
}

/// The compiler binary in `priv/bin` for a Node `process.platform-process.arch`
/// pair, such as `linux-x64`.
pub fn compiler_name(platform: String) -> Result(String, String) {
  case platform {
    "linux-x64" | "linux-arm64" | "darwin-x64" | "darwin-arm64" ->
      Ok("afterglow-" <> platform)
    "win32-x64" -> Ok("afterglow-win32-x64.exe")
    _ ->
      Error(
        "afterglow has no compiler for "
        <> platform
        <> ". It runs on Linux and macOS (x64 and arm64) and Windows (x64).",
      )
  }
}

/// An `erl -eval` expression printing the stdlib, kernel and erts directories of
/// the OTP that `erl` runs, one per line. afterglow compiles those modules too.
pub const otp_libs_eval =
  "io:format(\"~s~n~s~n~s~n\", [code:lib_dir(stdlib), code:lib_dir(kernel), code:lib_dir(erts)]), halt()."

pub fn otp_ebin_dirs(eval_output: String) -> List(String) {
  eval_output
  |> string.split("\n")
  |> list.map(string.trim)
  |> list.filter(fn(line) { line != "" })
  |> list.map(fn(dir) { dir <> "/ebin" })
}

pub fn compile_args(
  runtime runtime: String,
  beam_dirs beam_dirs: List(String),
  out out: String,
) -> List(String) {
  [
    "build",
    "-v",
    "--rt",
    runtime,
    "--entry",
    start_module <> ":start/0",
    "-o",
    out,
    ..list.flat_map(beam_dirs, fn(dir) { ["--beams", dir] })
  ]
}

/// The Wasm features the runtime and the compiled app use; workerd supports all of
/// them. wasm-merge and wasm-opt both need the list.
const wasm_features = [
  "--enable-tail-call", "--enable-bulk-memory",
  "--enable-nontrapping-float-to-int", "--enable-sign-ext",
  "--enable-mutable-globals", "--enable-reference-types", "--enable-multivalue",
]

/// Links the compiled app with the runtime. The compiler imports the runtime's
/// functions from a module named `afterglow_runtime`.
pub fn merge_args(
  runtime runtime: String,
  app app: String,
  out out: String,
) -> List(String) {
  list.append(wasm_features, [
    runtime,
    "afterglow_runtime",
    app,
    "app",
    "-o",
    out,
  ])
}

pub fn optimise_args(input input: String, out out: String) -> List(String) {
  list.append(wasm_features, ["-O3", input, "-o", out])
}

pub const binaryen_version = "132.0.0"

/// One directory per version, so changing binaryen_version installs it afresh.
pub fn binaryen_dir() -> String {
  "./build/dev/bin/binaryen-" <> binaryen_version
}

pub fn binaryen_tarball_url() -> String {
  "https://registry.npmjs.org/binaryen/-/binaryen-"
  <> binaryen_version
  <> ".tgz"
}

/// What the build needs from the binaryen npm package. Its tools are JavaScript
/// with WebAssembly inside, run with the same runtime as the CLI; bin/package.json
/// marks them CommonJS.
pub fn binaryen_files() -> List(String) {
  ["bin/wasm-merge", "bin/wasm-opt", "bin/package.json"]
}

const missing_prefixes = [
  "warning: NIF/BIF not implemented by afterglow_runtime: ",
  "warning: no module for ", "warning: undefined function: ",
]

/// The functions the compiler reported it can't provide, from its `-v` output.
/// Some are never called at run time, so they are a note, not an error.
pub fn missing_functions(compiler_output: String) -> List(String) {
  compiler_output
  |> string.split("\n")
  |> list.filter_map(fn(line) {
    let line = string.trim(line)
    list.find_map(missing_prefixes, fn(prefix) {
      case string.starts_with(line, prefix) {
        True -> Ok(string.drop_start(line, string.length(prefix)))
        False -> Error(Nil)
      }
    })
  })
  |> list.unique
  |> list.sort(string.compare)
}

pub fn describe_missing(functions: List(String)) -> String {
  "afterglow does not provide these functions. The app still builds, and a request that calls one gets a 500 naming it:\n"
  <> string.join(list.map(functions, fn(name) { "  - " <> name }), "\n")
}
