import filepath
import giolt/internal/effect.{type Effect}
import giolt/internal/process
import gleam/list
import simplifile

pub fn installed(directory: String, files: List(String)) -> Bool {
  list.all(files, fn(file) {
    simplifile.is_file(filepath.join(directory, file)) == Ok(True)
  })
}

@external(javascript, "./ffi_npm.mjs", "install")
pub fn install(
  _url: String,
  _directory: String,
  _files: List(String),
) -> Effect(Result(Nil, String)) {
  panic as process.javascript_only
}
