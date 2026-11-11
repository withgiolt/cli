-module(giolt_ffi_effect).
-export([resolve/1, map/2, await/2]).

resolve(Value) -> Value.

map(Value, Next) -> Next(Value).

await(Value, Next) -> Next(Value).
