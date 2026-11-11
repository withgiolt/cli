pub type Runtime {
  Node
  Bun
}

pub type Error {
  NoJavascriptRuntime
}

pub fn pick(node node: Bool, bun bun: Bool) -> Result(Runtime, Error) {
  case node, bun {
    True, _ -> Ok(Node)
    False, True -> Ok(Bun)
    False, False -> Error(NoJavascriptRuntime)
  }
}

pub fn gleam_args(runtime: Runtime, args: List(String)) -> List(String) {
  let runtime = case runtime {
    Node -> "nodejs"
    Bun -> "bun"
  }
  [
    "run",
    "--target",
    "javascript",
    "--runtime",
    runtime,
    "--module",
    "giolt",
    "--",
    ..args
  ]
}

pub fn describe_error(error: Error) -> String {
  case error {
    NoJavascriptRuntime ->
      "giolt runs on JavaScript and needs Node.js 20+ or Bun, but neither "
      <> "`node` nor `bun` is installed. Install one: https://nodejs.org or https://bun.sh"
  }
}
