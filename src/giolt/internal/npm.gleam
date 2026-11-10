import filepath
import gleam/javascript/promise.{type Promise}
import gleam/list
import simplifile

pub fn installed(directory: String, files: List(String)) -> Bool {
  list.all(files, fn(file) {
    simplifile.is_file(filepath.join(directory, file)) == Ok(True)
  })
}

@external(javascript, "./ffi_npm.mjs", "install")
pub fn install(
  url: String,
  directory: String,
  files: List(String),
) -> Promise(Result(Nil, String))
