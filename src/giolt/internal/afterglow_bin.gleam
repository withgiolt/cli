import filepath
import giolt/internal/afterglow
import giolt/internal/config.{type Config}
import giolt/internal/io
import giolt/internal/process
import giolt/internal/tooling
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub const steps = 5

const app_wasm = "build/app.wasm"

const merged_wasm = "build/merged.wasm"

const optimised_wasm = "build/optimised.wasm"

pub fn build(config: Config, outdir: String) -> Promise(Result(Nil, String)) {
  case generate_package(config) {
    Error(message) -> promise.resolve(Error(message))
    Ok(Nil) -> {
      use _ <- promise.try_await(compile_to_beam())
      io.println_progress(2, steps, "Compiled to BEAM")

      use _ <- promise.try_await(compile_to_wasm())
      io.println_progress(3, steps, "Compiled to WebAssembly")

      use _ <- promise.try_await(link_and_optimise())
      io.println_progress(4, steps, "Linked and optimised")

      promise.resolve({
        use _ <- result.try(copy_output(outdir))
        io.println_progress(5, steps, "Copied the Worker")
        Ok(Nil)
      })
    }
  }
}

pub fn check_tooling() -> Result(Nil, String) {
  let missing =
    list.filter(tooling.required(), fn(tool) {
      let #(command, args) = tooling.probe(tool)
      !process.available(command, args)
    })

  case missing {
    [] -> Ok(Nil)
    _ -> Error(tooling.describe_missing(missing))
  }
}

fn generate_package(config: Config) -> Result(Nil, String) {
  let files = [
    #(
      "gleam.toml",
      afterglow.gleam_toml(package: config.package, project_path: "../../.."),
    ),
    #(
      "src/" <> afterglow.start_module <> ".gleam",
      afterglow.start_source(config.entry),
    ),
  ]

  use _ <- result.try(
    simplifile.create_directory_all(filepath.join(afterglow.build_dir, "src"))
    |> result.map_error(describe_file_error),
  )

  list.try_each(files, fn(file) {
    simplifile.write(filepath.join(afterglow.build_dir, file.0), file.1)
    |> result.map_error(describe_file_error)
  })
}

fn compile_to_beam() -> Promise(Result(Nil, String)) {
  io.println_info("Compiling the app to BEAM...")
  process.run_in(afterglow.build_dir, "gleam", [
    "build",
    "--target",
    "erlang",
  ])
}

fn compile_to_wasm() -> Promise(Result(Nil, String)) {
  io.println_info("Compiling the app to WebAssembly with afterglow...")

  use otp <- promise.try_await(otp_ebin_dirs())
  case compiler_path(), project_ebin_dirs() {
    Error(message), _ | _, Error(message) -> promise.resolve(Error(message))
    Ok(compiler), Ok(project) -> {
      use _ <- promise.try_await(make_executable(compiler))

      let args =
        afterglow.compile_args(
          runtime: filepath.join(afterglow.priv_dir(), "afterglow_runtime.wasm"),
          beam_dirs: list.append(project, otp),
          out: filepath.join(afterglow.build_dir, app_wasm),
        )
      use compiled <- promise.map(process.output(".", compiler, args))
      use #(_, warnings) <- result.map(compiled)
      case afterglow.missing_functions(warnings) {
        [] -> Nil
        missing -> io.println_warning(afterglow.describe_missing(missing))
      }
    }
  }
}

fn otp_ebin_dirs() -> Promise(Result(List(String), String)) {
  use printed <- promise.map(
    process.output(".", "erl", ["-noshell", "-eval", afterglow.otp_libs_eval]),
  )
  use #(stdout, _) <- result.map(printed)
  afterglow.otp_ebin_dirs(stdout)
}

fn compiler_path() -> Result(String, String) {
  use name <- result.map(afterglow.compiler_name(process.platform()))
  filepath.join(afterglow.priv_dir(), "bin/" <> name)
}

fn make_executable(path: String) -> Promise(Result(Nil, String)) {
  case string.ends_with(path, ".exe") {
    True -> promise.resolve(Ok(Nil))
    False -> chmod_executable(path)
  }
}

/// The ebin directory of every package the generated build package compiled,
/// the user's project and its dependencies included.
fn project_ebin_dirs() -> Result(List(String), String) {
  let root = filepath.join(afterglow.build_dir, "build/dev/erlang")
  simplifile.read_directory(root)
  |> result.map(fn(packages) {
    packages
    |> list.sort(string.compare)
    |> list.map(fn(package) { filepath.join(root, package <> "/ebin") })
    |> list.filter(fn(dir) { simplifile.is_directory(dir) == Ok(True) })
  })
  |> result.replace_error("Could not list the compiled packages in " <> root)
}

fn link_and_optimise() -> Promise(Result(Nil, String)) {
  use _ <- promise.try_await(ensure_binaryen())
  let runtime = filepath.join(afterglow.priv_dir(), "afterglow_runtime.wasm")
  let at = filepath.join(afterglow.build_dir, _)

  use _ <- promise.try_await(run_binaryen(
    "wasm-merge",
    afterglow.merge_args(runtime:, app: at(app_wasm), out: at(merged_wasm)),
  ))
  run_binaryen(
    "wasm-opt",
    afterglow.optimise_args(input: at(merged_wasm), out: at(optimised_wasm)),
  )
}

fn ensure_binaryen() -> Promise(Result(Nil, String)) {
  let dir = afterglow.binaryen_dir()
  case simplifile.is_file(filepath.join(dir, "bin/wasm-opt")) {
    Ok(True) -> promise.resolve(Ok(Nil))
    _ -> {
      io.println_info(
        "Downloading Binaryen " <> afterglow.binaryen_version <> "...",
      )
      install_from_npm(
        afterglow.binaryen_tarball_url(),
        dir,
        afterglow.binaryen_files(),
      )
    }
  }
}

fn run_binaryen(
  tool: String,
  args: List(String),
) -> Promise(Result(Nil, String)) {
  let script = filepath.join(afterglow.binaryen_dir(), "bin/" <> tool)
  process.run(process.runtime_path(), [script, ..args])
}

fn copy_output(outdir: String) -> Result(Nil, String) {
  let files = [
    #(filepath.join(afterglow.build_dir, optimised_wasm), "app.wasm"),
    #(filepath.join(afterglow.priv_dir(), "index.js"), "index.js"),
  ]

  let _ = simplifile.delete(outdir)
  use _ <- result.try(
    simplifile.create_directory_all(outdir)
    |> result.map_error(describe_file_error),
  )

  list.try_each(files, fn(file) {
    simplifile.copy_file(file.0, filepath.join(outdir, file.1))
    |> result.map_error(fn(error) {
      "Could not copy " <> file.0 <> ": " <> simplifile.describe_error(error)
    })
  })
}

fn describe_file_error(error: simplifile.FileError) -> String {
  "Could not write the afterglow build package: " <> string.inspect(error)
}

@target(javascript)
@external(javascript, "./ffi_afterglow.mjs", "install_from_npm")
fn install_from_npm(
  url: String,
  directory: String,
  files: List(String),
) -> Promise(Result(Nil, String))

@target(erlang)
fn install_from_npm(
  _url: String,
  _directory: String,
  _files: List(String),
) -> Promise(Result(Nil, String)) {
  promise.resolve(Error("Giolt only supports the `javascript` target."))
}

@target(javascript)
@external(javascript, "./ffi_afterglow.mjs", "make_executable")
fn chmod_executable(path: String) -> Promise(Result(Nil, String))

@target(erlang)
fn chmod_executable(_path: String) -> Promise(Result(Nil, String)) {
  promise.resolve(Error("Giolt only supports the `javascript` target."))
}
