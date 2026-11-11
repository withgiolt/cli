import giolt/internal/rerun.{Bun, NoJavascriptRuntime, Node}

pub fn node_is_used_when_installed_test() {
  assert rerun.pick(node: True, bun: True) == Ok(Node)
  assert rerun.pick(node: True, bun: False) == Ok(Node)
}

pub fn bun_is_used_without_node_test() {
  assert rerun.pick(node: False, bun: True) == Ok(Bun)
}

pub fn no_runtime_is_an_error_test() {
  assert rerun.pick(node: False, bun: False) == Error(NoJavascriptRuntime)
}

pub fn the_command_reruns_giolt_on_javascript_test() {
  assert rerun.gleam_args(Node, ["deploy", "--preview"])
    == [
      "run", "--target", "javascript", "--runtime", "nodejs", "--module",
      "giolt", "--", "deploy", "--preview",
    ]
}

pub fn bun_is_passed_as_the_runtime_test() {
  assert rerun.gleam_args(Bun, [])
    == [
      "run", "--target", "javascript", "--runtime", "bun", "--module", "giolt",
      "--",
    ]
}
