//// A value that a command produces, possibly later. On JavaScript it is a
//// Promise, because Node's subprocesses and fetch are asynchronous; on Erlang
//// those calls block, so it is the value itself.

pub type Effect(a)

@external(erlang, "giolt_ffi_effect", "resolve")
@external(javascript, "./ffi_effect.mjs", "resolve")
pub fn resolve(value: a) -> Effect(a)

@external(erlang, "giolt_ffi_effect", "map")
@external(javascript, "./ffi_effect.mjs", "map")
pub fn map(effect: Effect(a), next: fn(a) -> b) -> Effect(b)

@external(erlang, "giolt_ffi_effect", "await")
@external(javascript, "./ffi_effect.mjs", "await_effect")
pub fn await(effect: Effect(a), next: fn(a) -> Effect(b)) -> Effect(b)

pub fn try_await(
  effect: Effect(Result(a, e)),
  next: fn(a) -> Effect(Result(b, e)),
) -> Effect(Result(b, e)) {
  use result <- await(effect)
  case result {
    Ok(value) -> next(value)
    Error(error) -> resolve(Error(error))
  }
}
