import gleam/list
import gleam/string

pub type Tool {
  Erlang
  Rebar3
}

pub fn required() -> List(Tool) {
  [Erlang, Rebar3]
}

// rebar3 installs as rebar3.cmd on Windows, and Node only starts .cmd files
// through cmd.exe.
pub fn probe(tool: Tool, windows windows: Bool) -> #(String, List(String)) {
  case tool, windows {
    Erlang, _ -> #("erl", ["-noshell", "-eval", "halt(0)."])
    Rebar3, False -> #("rebar3", ["version"])
    Rebar3, True -> #("cmd.exe", ["/d", "/s", "/c", "rebar3", "version"])
  }
}

pub fn describe_missing(missing: List(Tool)) -> String {
  "Building for the Erlang target needs tools that are not installed:\n"
  <> string.join(list.map(missing, hint), "\n")
}

fn hint(tool: Tool) -> String {
  case tool {
    Erlang -> "  - Erlang/OTP: https://www.erlang.org/downloads"
    Rebar3 -> "  - rebar3: https://rebar3.org/docs/getting-started/"
  }
}
