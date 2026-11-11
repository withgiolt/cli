import argv
import giolt/internal/cli
import giolt/internal/commands
import giolt/internal/effect.{type Effect}
import giolt/internal/io
import giolt/internal/process
import giolt/internal/rerun
import gleam/io as stdio

pub fn main() -> Effect(Nil) {
  let args = argv.load().arguments
  case process.on_javascript() {
    True -> run_cli(args)
    False -> effect.resolve(rerun_on_javascript(args))
  }
}

// Every command needs Node or Bun (subprocesses, fetch, the dev server), so
// on Erlang giolt runs itself again on JavaScript.
fn rerun_on_javascript(args: List(String)) -> Nil {
  let runtime =
    rerun.pick(
      node: process.available("node", ["--version"]),
      bun: process.available("bun", ["--version"]),
    )
  case runtime {
    Error(error) -> {
      io.println_error(rerun.describe_error(error))
      process.exit(1)
    }
    Ok(runtime) ->
      case process.run_attached("gleam", rerun.gleam_args(runtime, args)) {
        Ok(status) -> process.exit(status)
        Error(message) -> {
          io.println_error(message)
          process.exit(1)
        }
      }
  }
}

fn run_cli(args: List(String)) -> Effect(Nil) {
  case cli.parse(args) {
    cli.Usage(text) -> effect.resolve(stdio.println(text))
    cli.Invalid(text) -> {
      stdio.println_error(text)
      process.exit(2)
      effect.resolve(Nil)
    }
    cli.Run(command) -> {
      use result <- effect.map(run(command))
      case result {
        Ok(Nil) -> Nil
        Error(message) -> {
          io.println_error(message)
          process.exit(1)
        }
      }
    }
  }
}

fn run(command: cli.Command) -> Effect(Result(Nil, String)) {
  case command {
    cli.Build(config:) -> commands.build(config:)
    cli.Dev(config:) -> commands.dev(config:)
    cli.Deploy(preview:, artifact:, project:, config:) ->
      commands.deploy(preview:, artifact:, project:, config:)
    cli.Link(name:, config:) -> commands.link_project(name:, config:)
    cli.Unlink(config:) -> commands.unlink_project(config:)
    cli.Login(token:) -> commands.login(token:)
    cli.Logout -> commands.logout()
    cli.Whoami -> commands.whoami()
    cli.ListProjects -> commands.list_projects()
    cli.CreateProject(name:) -> commands.create_project(name:)
    cli.RenameProject(from:, to:) -> commands.rename_project(from:, to:)
    cli.DeleteProject(name:, yes:) -> commands.delete_project(name:, yes:)
    cli.ShowUsage(json:) -> commands.usage(json:)
    cli.Help -> effect.resolve(Ok(stdio.println(cli.usage_text())))
  }
}
