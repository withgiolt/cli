import giolt/internal/process
import gleam/option.{type Option}

pub type Worker {
  NoWorker
  Bundle(path: String)
  // An afterglow build: app.wasm and host.mjs in this directory.
  Wasm(directory: String)
}

pub fn serve(
  port port: Int,
  static_dir static_dir: Option(String),
  worker worker: Worker,
  live_reload live_reload: Bool,
  spa spa: Bool,
) -> Nil {
  let #(kind, path) = case worker {
    NoWorker -> #("", "")
    Bundle(path) -> #("bundle", path)
    Wasm(directory) -> #("wasm", directory)
  }
  do_serve(port, option.unwrap(static_dir, ""), kind, path, live_reload, spa)
}

@external(javascript, "./ffi_server.mjs", "serve")
fn do_serve(
  _port: Int,
  _static_dir: String,
  _worker_kind: String,
  _worker_path: String,
  _live_reload: Bool,
  _spa: Bool,
) -> Nil {
  panic as process.javascript_only
}

@external(javascript, "./ffi_server.mjs", "notify_reload")
pub fn notify_reload() -> Nil {
  panic as process.javascript_only
}
