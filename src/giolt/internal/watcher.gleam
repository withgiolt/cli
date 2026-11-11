import giolt/internal/effect.{type Effect}

@external(javascript, "./ffi_watcher.mjs", "watch")
pub fn watch(
  paths paths: List(String),
  on_change on_change: fn(List(String)) -> Effect(Nil),
) -> fn() -> Nil
