import filepath
import gleam/javascript/promise.{type Promise}
import gleam/list
import simplifile

pub fn installed(directory: String, files: List(String)) -> Bool {
  list.all(files, fn(file) {
    simplifile.is_file(filepath.join(directory, file)) == Ok(True)
  })
}

@target(javascript)
@external(javascript, "./ffi_npm.mjs", "install")
pub fn install(
  url: String,
  directory: String,
  files: List(String),
) -> Promise(Result(Nil, String))

@target(erlang)
pub fn install(
  _url: String,
  _directory: String,
  _files: List(String),
) -> Promise(Result(Nil, String)) {
  promise.resolve(Error("Giolt only supports the `javascript` target."))
}
