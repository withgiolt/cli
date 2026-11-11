import giolt/internal/effect.{type Effect}
import giolt/internal/process

@external(javascript, "./ffi_watcher.mjs", "watch")
pub fn watch(
  paths _paths: List(String),
  on_change _on_change: fn(List(String)) -> Effect(Nil),
) -> fn() -> Nil {
  panic as process.javascript_only
}
