import gleam/list
import gleam/result
import gleam/set.{type Set}
import gleam/string
import tom

pub const package_name = "giolt_afterglow_build"

pub const build_dir = "./build/.giolt/afterglow"

pub const start_module = "giolt_afterglow_start"

const runtime_range = ">= 0.1.0 and < 1.0.0"

pub fn priv_dir() -> String {
  build_dir <> "/build/packages/afterglow/priv"
}

pub type Step {
  CheckedHandle
  CompiledToBeam
  CompiledToWasm
  LinkedAndOptimised
  CopiedWorker
}

pub const steps = [
  CheckedHandle,
  CompiledToBeam,
  CompiledToWasm,
  LinkedAndOptimised,
  CopiedWorker,
]

pub fn step_number(step: Step) -> Int {
  case step {
    CheckedHandle -> 1
    CompiledToBeam -> 2
    CompiledToWasm -> 3
    LinkedAndOptimised -> 4
    CopiedWorker -> 5
  }
}

pub fn step_label(step: Step) -> String {
  case step {
    CheckedHandle -> "Checked handle"
    CompiledToBeam -> "Compiled to BEAM"
    CompiledToWasm -> "Compiled to WebAssembly"
    LinkedAndOptimised -> "Linked and optimised"
    CopiedWorker -> "Copied the Worker"
  }
}

// A path dependency's own dependencies are resolved afresh, whatever its
// manifest.toml says, so the build package pins every Hex package the user's
// manifest locks. Without the pins the Wasm build could run other versions
// than the user's tests did.
pub fn gleam_toml(
  package package: String,
  project_path project_path: String,
  locked locked: List(#(String, String)),
) -> String {
  let pinned = list.map(locked, fn(pair) { #(pair.0, "== " <> pair.1) })
  let defaults =
    [#("gleam_stdlib", ">= 1.0.0 and < 2.0.0"), #("afterglow", runtime_range)]
    |> list.filter(fn(pair) { list.key_find(locked, pair.0) |> result.is_error })
  let dependencies =
    list.map(list.append(defaults, pinned), fn(pair) {
      pair.0 <> " = \"" <> pair.1 <> "\"\n"
    })

  "name = \"" <> package_name <> "\"
version = \"0.0.0\"
target = \"erlang\"

[dependencies]
" <> string.concat(dependencies) <> package <> " = { path = \"" <> project_path <> "\" }
"
}

// The Hex packages a manifest.toml locks, with their versions. Git and path
// packages are left to the user's project to declare.
pub fn locked_versions(
  manifest manifest: String,
  dependencies dependencies: List(String),
) -> Result(List(#(String, String)), Nil) {
  use toml <- result.try(
    tom.parse(string.replace(manifest, "\r\n", "\n"))
    |> result.replace_error(Nil),
  )
  use packages <- result.try(
    tom.get_array(toml, ["packages"]) |> result.replace_error(Nil),
  )
  use packages <- result.try(list.try_map(packages, locked_package))

  // The manifest also locks dev dependencies, which the build package must
  // not pull in, so only what the user's dependencies reach is pinned.
  let reached = reach(packages, dependencies, set.new())
  packages
  |> list.filter(fn(package) {
    package.hex && set.contains(reached, package.name)
  })
  |> list.map(fn(package) { #(package.name, package.version) })
  |> Ok
}

type LockedPackage {
  LockedPackage(
    name: String,
    version: String,
    hex: Bool,
    requirements: List(String),
  )
}

fn locked_package(package: tom.Toml) -> Result(LockedPackage, Nil) {
  let fields = tom.as_table(package)
  let field = fn(key) {
    result.try(fields, tom.get_string(_, [key])) |> result.replace_error(Nil)
  }
  use name <- result.try(field("name"))
  use version <- result.try(field("version"))
  use requirements <- result.try(
    result.try(fields, tom.get_array(_, ["requirements"]))
    |> result.try(list.try_map(_, tom.as_string))
    |> result.replace_error(Nil),
  )
  Ok(LockedPackage(
    name:,
    version:,
    hex: field("source") == Ok("hex"),
    requirements:,
  ))
}

fn reach(
  packages: List(LockedPackage),
  pending: List(String),
  reached: Set(String),
) -> Set(String) {
  case pending {
    [] -> reached
    [name, ..rest] ->
      case set.contains(reached, name) {
        True -> reach(packages, rest, reached)
        False -> {
          let requirements =
            list.find(packages, fn(package) { package.name == name })
            |> result.map(fn(package) { package.requirements })
            |> result.unwrap([])
          reach(
            packages,
            list.append(requirements, rest),
            set.insert(reached, name),
          )
        }
      }
  }
}

pub fn start_source(entry: String) -> String {
  "import afterglow
import " <> entry <> " as user

pub fn start() {
  afterglow.serve(fn(req) { user.handle(req) })
}
"
}

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

// afterglow compiles the OTP modules the app calls too, so it needs their
// directories from the OTP that `erl` runs.
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

// The Wasm features the runtime and the compiled app use; workerd supports all
// of them. wasm-merge and wasm-opt both need the list.
const wasm_features = [
  "--enable-tail-call", "--enable-bulk-memory",
  "--enable-nontrapping-float-to-int", "--enable-sign-ext",
  "--enable-mutable-globals", "--enable-reference-types", "--enable-multivalue",
]

// The compiler imports the runtime's functions from a module named
// `afterglow_runtime`.
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

// One directory per version, so changing binaryen_version installs it afresh.
pub fn binaryen_dir() -> String {
  "./build/dev/bin/binaryen-" <> binaryen_version
}

pub fn binaryen_tarball_url() -> String {
  "https://registry.npmjs.org/binaryen/-/binaryen-"
  <> binaryen_version
  <> ".tgz"
}

// The tools are JavaScript with WebAssembly inside, run with the same runtime
// as the CLI; bin/package.json marks them CommonJS.
pub fn binaryen_files() -> List(String) {
  ["bin/wasm-merge", "bin/wasm-opt", "bin/package.json"]
}

const warning_prefix = "warning: "

// The wording of afterglow 0.1's warnings, in crates/afterglow/src/program.rs.
const missing_prefixes = [
  "NIF/BIF not implemented by afterglow_runtime: ", "no module for ",
  "undefined function: ",
]

// Missing functions are a note, not an error: some are never called at run
// time. Any other warning is passed on as afterglow wrote it, so a warning
// whose wording changes still reaches the user.
pub type Warnings {
  Warnings(missing: List(String), other: List(String))
}

pub fn warnings(compiler_output: String) -> Warnings {
  let warnings =
    compiler_output
    |> string.split("\n")
    |> list.map(string.trim)
    |> list.filter_map(fn(line) {
      case string.starts_with(line, warning_prefix) {
        True -> Ok(string.drop_start(line, string.length(warning_prefix)))
        False -> Error(Nil)
      }
    })
    |> list.unique

  let #(missing, other) =
    list.fold(warnings, #([], []), fn(acc, warning) {
      case missing_function(warning) {
        Ok(name) -> #([name, ..acc.0], acc.1)
        Error(Nil) -> #(acc.0, [warning, ..acc.1])
      }
    })

  Warnings(
    missing: list.sort(list.unique(missing), string.compare),
    other: list.reverse(other),
  )
}

fn missing_function(warning: String) -> Result(String, Nil) {
  list.find_map(missing_prefixes, fn(prefix) {
    case string.starts_with(warning, prefix) {
      True -> Ok(string.drop_start(warning, string.length(prefix)))
      False -> Error(Nil)
    }
  })
}

pub fn describe_missing(functions: List(String)) -> String {
  "afterglow does not provide these functions. The app still builds, and a request that calls one gets a 500 naming it:\n"
  <> string.join(list.map(functions, fn(name) { "  - " <> name }), "\n")
}

pub fn describe_other(warnings: List(String)) -> String {
  "afterglow warned:\n"
  <> string.join(list.map(warnings, fn(warning) { "  - " <> warning }), "\n")
}
