import giolt/internal/process
import gleam/option.{type Option}

pub fn serve(
  port port: Int,
  static_dir static_dir: Option(String),
  worker_path worker_path: String,
  live_reload live_reload: Bool,
  spa spa: Bool,
) -> Nil {
  do_serve(port, option.unwrap(static_dir, ""), worker_path, live_reload, spa)
}

@external(javascript, "./ffi_server.mjs", "serve")
fn do_serve(
  _port: Int,
  _static_dir: String,
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
