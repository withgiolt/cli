import giolt/internal/npm
import gleam/javascript/promise.{type Promise}
import gleam/string
import simplifile

const fixture = "./test/fixtures/npm_package.tgz"

@external(javascript, "./npm_test_ffi.mjs", "serve")
fn serve(fixture: String) -> Promise(#(String, fn() -> Nil))

fn fresh(directory: String) -> String {
  let _ = simplifile.delete(directory)
  let _ = simplifile.delete(directory <> ".partial")
  directory
}

fn install(
  path: String,
  directory: String,
  files: List(String),
) -> Promise(Result(Nil, String)) {
  use #(base, close) <- promise.await(serve(fixture))
  use installed <- promise.map(npm.install(base <> path, directory, files))
  close()
  installed
}

pub fn only_the_listed_files_are_installed_test() {
  let directory = fresh("./test_tmp_npm_listed")
  let files = ["bin/tool", "bin/package.json"]
  use installed <- promise.map(install("/package.tgz", directory, files))

  let tool = simplifile.read(directory <> "/bin/tool")
  let readme = simplifile.is_file(directory <> "/README.md")
  let done = npm.installed(directory, files)
  let partial = simplifile.is_directory(directory <> ".partial")
  let _ = simplifile.delete(directory)

  assert installed == Ok(Nil)
  assert tool == Ok("tool")
  assert readme == Ok(False)
  assert done
  assert partial == Ok(False)
}

pub fn a_file_the_tarball_lacks_leaves_nothing_installed_test() {
  let directory = fresh("./test_tmp_npm_lacking")
  use installed <- promise.map(
    install("/package.tgz", directory, ["bin/tool", "bin/missing"]),
  )

  let exists = simplifile.is_directory(directory)
  let partial = simplifile.is_directory(directory <> ".partial")

  let assert Error(message) = installed
  assert string.contains(message, "bin/missing")
  assert exists == Ok(False)
  assert partial == Ok(False)
}

pub fn a_cut_off_download_leaves_nothing_installed_test() {
  let directory = fresh("./test_tmp_npm_cut_off")
  use installed <- promise.map(
    install("/truncated.tgz", directory, ["bin/tool", "bin/package.json"]),
  )

  let exists = simplifile.is_directory(directory)
  let partial = simplifile.is_directory(directory <> ".partial")

  let assert Error(_) = installed
  assert exists == Ok(False)
  assert partial == Ok(False)
}

pub fn a_failed_request_names_the_status_test() {
  let directory = fresh("./test_tmp_npm_status")
  use installed <- promise.map(install("/gone.tgz", directory, ["bin/tool"]))

  let assert Error(message) = installed
  assert string.contains(message, "HTTP 404")
}

pub fn an_incomplete_install_is_replaced_test() {
  let directory = fresh("./test_tmp_npm_replace")
  let files = ["bin/tool", "bin/package.json"]
  let assert Ok(_) = simplifile.create_directory_all(directory <> "/bin")
  let assert Ok(_) = simplifile.write(directory <> "/bin/tool", "stale")
  let before = npm.installed(directory, files)

  use installed <- promise.map(install("/package.tgz", directory, files))

  let tool = simplifile.read(directory <> "/bin/tool")
  let after = npm.installed(directory, files)
  let _ = simplifile.delete(directory)

  assert !before
  assert installed == Ok(Nil)
  assert tool == Ok("tool")
  assert after
}
