import giolt/internal/esbuild
import giolt/internal/esgleam/esgleam/mod/platform
import giolt/internal/io
import giolt/internal/npm
import gleam/javascript/promise.{type Promise}
import gleam/result

pub fn ensure_installed() -> Promise(Result(String, String)) {
  let exe_name = platform.get_exe_name()
  let directory = esbuild.install_dir()
  let files = [esbuild.package_file(exe_name)]

  case npm.installed(directory, files) {
    True -> promise.resolve(Ok(esbuild.exe_path(exe_name)))
    False -> {
      io.println_info("Downloading esbuild " <> esbuild.version <> "...")
      let url = esbuild.tarball_url(platform.get_package_name())
      use installed <- promise.map(npm.install(url, directory, files))
      result.replace(installed, esbuild.exe_path(exe_name))
    }
  }
}

pub fn run(exe: String, args: List(String)) -> Promise(Result(Nil, String)) {
  exec(exe, args)
}

@target(javascript)
@external(javascript, "./ffi_esbuild.mjs", "exec")
fn exec(command: String, args: List(String)) -> Promise(Result(Nil, String))

@target(erlang)
fn exec(_command: String, _args: List(String)) -> Promise(Result(Nil, String)) {
  promise.resolve(Error("Giolt only supports the `javascript` target."))
}
