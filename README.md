# giolt

Build, run and deploy Gleam apps on [Giolt](https://giolt.com).

Install it globally with npm or Bun. It needs Node 20 or newer:

```sh
npm i -g @giolt/cli
bun i -g @giolt/cli
giolt build
```

`bun i -g` links a script that starts with `#!/usr/bin/env node`, so a machine
with only Bun installed needs Node too, or can run `bunx --bun @giolt/cli build`
instead.

Or add it as a dev dependency and run it. It works on Node 20 or newer, which is
Gleam's default JavaScript runtime, and on Bun:

```sh
gleam add --dev giolt
gleam run -m giolt build
gleam run --runtime bun -m giolt build
```

The CLI runs on JavaScript. In an Erlang-target project, `gleam run -m giolt`
starts on Erlang and runs itself again as `gleam run --target javascript`, with
Node when it is installed and otherwise Bun. When neither is installed, it
stops and says so.

Your entry module exports one function named `handle`:

```gleam
// JavaScript target
pub fn handle(req: Request(conversation.RequestBody)) -> Response(conversation.ResponseBody)

// Erlang target (afterglow)
pub fn handle(req: wisp.Request) -> wisp.Response
```

`giolt build` checks this signature against `gleam export package-interface`
and fails with the expected and found types when it does not match.

## Commands

| Command | Does |
| --- | --- |
| `giolt build [--config FILE]` | Checks `handle`, compiles and bundles into `outdir` |
| `giolt dev [--config FILE]` | Builds, watches `watch`, serves on `port` and reloads on change |
| `giolt deploy [--preview] [--artifact DIR] [--project NAME] [--config FILE]` | Builds, then uploads `outdir` to Giolt. With `artifact`, uploads that directory instead |
| `giolt link NAME [--config FILE]` | Writes `project = <id>` under `[tools.giolt]`, so `deploy` needs no flags. Commit the file so CI deploys there too |
| `giolt unlink [--config FILE]` | Removes that `project` line |
| `giolt help` | Prints the commands. `giolt <command> --help` prints that command's flags |

`gleam run -m giolt -h` prints help for `gleam run`, not for giolt, because
Gleam reads the flag first. Use `gleam run -m giolt help` or `gleam run -m
giolt` with no arguments instead.

`link` and `unlink` edit the file as text, so comments and layout stay as they
are. They write to the `--config` file when you pass one.

`deploy` picks its project and token like this:

- `--project NAME` wins over the linked `project`. The CLI looks the name up with
  your token.
- The token is `GIOLT_TOKEN` when set, otherwise the one `giolt login` stored.
- With no project, `deploy` stops and asks you to run `giolt link` or pass
  `--project`. Tokens cover the whole account, so none of them names a project.
- `GIOLT_TOKEN` goes to `GIOLT_API_URL`, then `api_url`. A stored login only
  goes to the URL it logged in against.

## Account and projects

| Command | Does |
| --- | --- |
| `giolt login` | Shows a code and opens the dashboard so you can approve it in the browser, then stores the token |
| `giolt login --token -` | Reads a token made on the dashboard's Tokens page from stdin and stores it. It starts with `giolt_`; anything else is refused. `--token TOKEN` also works, but leaves the token in your shell history |
| `giolt logout` | Revokes the stored token and deletes it. If the revoke fails, the file is still deleted and you are told to revoke the token on the dashboard |
| `giolt whoami` | Shows the account email, the token's name, scopes and expiry, and where the token came from |
| `giolt projects` | Lists your projects with their URL and latest deployment status |
| `giolt projects create NAME` | Creates a project |
| `giolt projects rename OLD NEW` | Renames a project. The old URL stops working and there is no redirect |
| `giolt projects delete NAME [--yes]` | Deletes a project and its deployments for good. Asks you to type the name, or needs `--yes` when there is no terminal |
| `giolt usage` | Shows the account's requests against the included amount for the current billing period; `--json` prints it for scripts |

Creating, renaming and deleting need an active subscription; the error says
where to set one up.

`giolt login` stores the token in `credentials.json`, readable only by you, in:

- `$XDG_CONFIG_HOME/giolt/`, or `~/.config/giolt/` when that is unset (Linux and macOS)
- `%APPDATA%\giolt\` (Windows)

```sh
pbpaste | gleam run -m giolt login --token -
```

Logging in again revokes the token it replaces.

`GIOLT_TOKEN` takes precedence over the stored token, so CI can set it without
logging in. Account commands never read `gleam.toml`, so a project's `api_url` cannot send
your token elsewhere:

- `giolt login` uses `GIOLT_API_URL`, or `https://dash.giolt.com` when that is
  unset, and stores that URL with the token.
- The stored token is only ever sent to the URL stored with it.
- `GIOLT_TOKEN` is sent to `GIOLT_API_URL`, or `https://dash.giolt.com`.

`giolt logout` only removes the stored token; it does not unset `GIOLT_TOKEN`.

## Configuration

Everything is optional and lives under `[tools.giolt]` in your `gleam.toml`, or
in the TOML file you pass with `--config FILE` when one package needs several
builds (the package `name` and `target` still come from `gleam.toml`, and keys
the file leaves out take their defaults):

| Key | Default | Meaning |
| --- | --- | --- |
| `entry` | your package name | Module that exports `handle`, such as `my_app/server` |
| `assets` | none | Directory of static files, copied to `outdir/static` and served by `dev` |
| `outdir` | `"./dist"` | Where the bundle goes. It is deleted before every build |
| `esbuild_args` | `[]` | Extra esbuild flags, appended after the fixed ones so they win |
| `spa` | `false` | Serve `index.html` for paths that match no file. Static-only apps: requires `artifact` (or `deploy --artifact`) |
| `watch` | `["src"]`, plus `assets` | Directories `dev` watches |
| `port` | `3000` | `dev` server port |
| `live_reload` | `true` | Reload the browser after a rebuild |
| `api_url` | `"https://dash.giolt.com"` | Giolt API used by `deploy`. The account commands ignore it |
| `prebuild` | none | Shell command run before every build, such as `gleam run -m docs/build` |
| `artifact` | none | Deploy this directory as a static site. Skips the `handle` check, the compile and the bundle |
| `project` | none | Id of the project `deploy` uploads to. Set by `giolt link` |

## Erlang target

A project with `target = "erlang"` builds with
[afterglow](https://github.com/withgiolt/afterglow), which compiles the app's
BEAM bytecode to WebAssembly. You need Erlang/OTP 28 or 29 and rebar3
installed, and `giolt build` tells you which one is missing. The first build downloads
Binaryen from npm into `build/dev/bin`. The output in `outdir` is `app.wasm`
and afterglow's Worker entry, `index.mjs` and `host.mjs`, plus `static/` when
`assets` is set. It needs afterglow 0.2.0 or later. afterglow runs on Linux and
macOS (x64 and arm64) and Windows (x64).

`giolt dev` skips Binaryen's optimisation pass, which takes most of a build,
so its `app.wasm` is larger than the one `build` and `deploy` make.

The build uses the versions your `manifest.toml` locks. If afterglow needs a
newer version of one of them, dependency resolution fails; run `gleam update`
in your project and build again.

When the app reaches a function afterglow does not provide, such as
`crypto:mac/4`, `giolt build` lists it and still builds. A request that calls
one gets a 500 whose body names the function. `deploy` uploads the output the
same way as a JavaScript build. `dev` runs the same build and serves `app.wasm`
through `host.mjs`, rebuilding on every change; each rebuild takes a few seconds.

## Issues

Report bugs and requests at
[github.com/withgiolt/issues](https://github.com/withgiolt/issues).
