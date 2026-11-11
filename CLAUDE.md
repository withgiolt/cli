# giolt

The `giolt` CLI: builds, runs and deploys Gleam apps on the Giolt platform.
Consumers run `gleam run -m giolt <command>` (`build`, `dev`, `deploy`) and
configure it under `[tools.giolt]` in their own `gleam.toml`. The CLI itself
is a JavaScript-target package that runs on Node or Bun; it builds consumer projects for
either target. Under an Erlang-target project, `main` re-runs the CLI on
JavaScript (`internal/rerun.gleam`). It was `giolt_sdk` until 3.0.1, now retired on Hex.

## Settings

- Tracker: GitHub issues in withgiolt/issues
- Tests: when a cheap test seam exists
- Commits: only when the maintainer says
- Pushes and pull requests: ask before pushing
- Closing issues: allowed
- Subagents: only when the maintainer asks

## Working here

GitHub issues hold intent, usually one issue per plan with a heading and checklist per feature; the code and the maintainer decide what is true.
Check off items the code already does. Ask before adding an entry for a request that isn't listed. Problems you notice outside the task get an entry too, asked the same way, rather than a fix in passing, so every diff stays reviewable. Order is a suggestion: if a request seems to depend on unfinished work, say so in one line and continue.

Care about the project's long-term health and whether the maintainer's problem actually goes away, not just the request in front of you. Suggest what they haven't asked for but will need. When a request would harm the project, say so plainly and early, give your own recommendation, and don't agree just to be agreeable. Hold your position if the pushback brings no new information. Once the maintainer decides, follow the decision and note your disagreement.

Ask the maintainer about product direction, scope, anything irreversible or outward-facing, such as pushing, deleting data, adding a dependency or closing issues, unless the settings above allow it, and any choice where different readings of the request would lead to materially different work. Ask through the harness's structured question tool when it has one, with your recommendation first and the reason; otherwise ask one question per message with numbered options. Make every other call yourself and name it in the report. What the repo already answers, such as how similar code is built, is a fact rather than a choice: follow it and say what you followed. Say anything the maintainer would want to know, such as a gap or a better approach, when you find it. Finishing a change is not a question: report it and stop, and leave committing and pushing to the settings or the maintainer's word.

The maintainer can override any setting for a single request, for example "go autonomous, commit and push everything" or "ask before each commit"; the override lasts until that request is done.

When a task finishes, say once what changed, what you skipped or couldn't check, and any risk. Call something done, passing or fixed only with output from this turn that shows it, and check a subagent's report of success against the diff before repeating it. After that, follow the maintainer's current topic: raise finished work again only when the current topic affects it or they ask, and keep options about it out of questions on other subjects.

In chat with the maintainer, be direct, honest and brief: lead with the answer or the result, cut filler, and drop grammar where the meaning survives without it. Brevity never cuts what they need to know, such as a failure, a risk, a skipped step, a gap you found or your disagreement. When something needs explaining, such as a design tradeoff, a root cause or why you disagree, take the space it needs.

When the m4 skills are installed, route requests through them even when phrased casually, because they carry the steps that keep work consistent: a bug or error goes through m4:fix, building or changing behavior through m4:do, cleaning up a diff or working through review findings through m4:tidy, hunting bugs in a diff through Claude Code's `/code-review`, planning through m4:shape, explaining code through m4:explore, and a repeated correction through m4:harden. One-line edits are made directly. Before writing prose that lands somewhere, such as docs, a README, comments, commit or pull request text, tracker entries, or a message to another person, run m4:unslop on the draft. In chat replies, follow its rules without invoking it, except that chat may drop grammar for brevity, which rule 33 forbids in prose that lands somewhere.

Work inline; spawn subagents only as the settings allow, except the plan review in m4:shape, because they spend tokens the maintainer wants to spend deliberately.

## Code

Aim for code that is obviously correct to a newcomer, since the next reader won't have this session's context.
Rank choices by correctness, then how easily the code reads and tests, then size; a one-liner that needs decoding is not simple.

Build only what was asked: features, options and configuration nobody requested wait until someone needs them. New code of a kind listed under Golden files takes that file's shape: its file layout, naming, error handling, state, UI and tests, and its helpers rather than new ones. Other new code takes the shape of the closest code that does something similar. When neither fits, ask before inventing a new shape. Before writing new code, look for it in this repo, then the standard library and platform, then installed dependencies.

Before editing, find every place the change must reach (callers, tests, fixtures, config, exports, and paths that must stay in step, such as a mock or sandbox mode beside production, each platform, and both sides of a feature flag) and finish all of them. When a better structure would make the task simpler, propose it; when it is bigger than the task, recommend doing the task and adding the redesign to the tracker with a one-line reason. Keep validation of untrusted input, error handling that prevents data loss, security and accessibility, including in code you move.

Comments explain why something non-obvious is true, such as a known limit and when it will matter. When code needs a comment to say what it does, rename or restructure it instead. Leave existing comments in code you don't change. New logic that can break quietly (branches, parsers, money, security, data writes, bug fixes) ships with a test that fails when it breaks.

Leave nothing behind but the change: no summary files, commented-out code, debug logs or session scripts. When a test fails, fix the code, or ask if the test's expectation looks wrong. Update the README in the same commit when user-visible behavior changes.

## Golden files

One file per kind of code that shows how this repo does it. Copy its shape when adding another of that kind, so the same job is always done the same way. When a new kind lands or a golden file moves, update its row in the same commit.

| To add | Copy |
|---|---|
| a pure decision function with its test | src/giolt/internal/signature.gleam, test/signature_test.gleam |
| a CLI command | src/giolt/internal/commands.gleam, src/giolt/internal/cli.gleam |
| an FFI file | src/giolt/internal/ffi_process.mjs |
| an Erlang FFI file (only what the re-run needs; other externals get a `panic as process.javascript_only` body) | src/giolt/internal/giolt_ffi_process.erl |

## Enforced rules

| Rule | Enforced by |
|---|---|
| Formatting | `gleam format --check` in .github/workflows/test.yml |
| Tests pass on Node and Bun | `gleam test --target javascript --runtime` matrix in .github/workflows/test.yml |

## Shape of the thing

`src/giolt.gleam` is the entry: it parses argv with `internal/cli.gleam` and
hands the command to `internal/commands.gleam`, the one effectful shell that
reads `gleam.toml`, runs subprocesses and prints. Everything it decides comes
from a pure function in `src/giolt/internal/`, each with a matching
`test/*_test.gleam`:

| Module | Owns |
| --- | --- |
| `cli.gleam` | The command tree (clip) and its flags; `parse` returns `Run`, `Usage` or `Invalid` |
| `config.gleam` | Reading the target, the `[dependencies]` names and every `[tools.giolt]` key, with defaults and typed errors |
| `signature.gleam` | Checking `handle/1` against the JSON from `gleam export package-interface` |
| `afterglow.gleam` | The generated afterglow build package (`gleam.toml` pinned to the user's `manifest.toml`, `start/0`), the build steps, the compiler name per platform, the compiler, wasm-merge and wasm-opt arguments, and how the compiler's warnings are reported |
| `afterglow_bin.gleam` + `ffi_afterglow.mjs` | Running that build: check the platform and tools, generate, `gleam build --target erlang`, compile to Wasm, install Binaryen, link, optimise, copy `app.wasm`, afterglow's `index.mjs` and `host.mjs`, and `assets` into `static/` |
| `tooling.gleam` | Which tools the Erlang target needs (Erlang/OTP, rebar3), how to probe each (rebar3 through `cmd.exe` on Windows) and how to say one is missing |
| `esbuild.gleam` | The esbuild argument list (`Plan -> List(String)`), no process spawned, and where the binary sits in its npm package |
| `esbuild_bin.gleam` | Installing and running the esbuild binary |
| `npm.gleam` + `ffi_npm.mjs` | Installing listed files from an npm tarball into a versioned directory under `build/dev/bin`, all of them or none |
| `bundle.gleam` | Bundling the compiled entry into `outdir` with the worker shim, plus static assets |
| `deploy.gleam` | Choosing the deploy's project and token (`route`), then posting the deploy to the Giolt API |
| `link.gleam` | Setting and removing `project` under `[tools.giolt]` as a text edit |
| `rerun.gleam` | On Erlang: picking Node or Bun and the `gleam run --target javascript` arguments that re-run the CLI there |
| `effect.gleam` + `ffi_effect.mjs` + `giolt_ffi_effect.erl` | `Effect(a)`, the command flow's result: a Promise on JavaScript, the plain value on Erlang, so the package compiles for an Erlang-target consumer |
| `api.gleam` + `ffi_api.mjs` | The `/api/v1` client: requests, response and error decoding, the device-login poll step, what a failed revoke means, which login URLs may be opened |
| `credentials.gleam` + `ffi_credentials.mjs` | Where `credentials.json` lives, reading and writing it, and choosing between it and `GIOLT_TOKEN` |
| `confirm.gleam` | Whether `projects delete` proceeds, asks you to type the name, or refuses |
| `shim.gleam` | The worker entry template esbuild bundles |
| `server.gleam` + `ffi_server.mjs` | The dev HTTP server (assets, hot reload of the JavaScript bundle or of afterglow's `app.wasm` through `host.mjs`, live-reload SSE) |
| `static_path.gleam` | Percent-decoding a dev server request path, refusing malformed and NUL-byte paths |
| `watcher.gleam` + `ffi_watcher.mjs` | Recursive file watching |
| `process.gleam` + `ffi_process.mjs` + `giolt_ffi_process.erl` | Running subprocesses and shell hooks, capturing a command's output, probing tools, reading a line from stdin, opening a URL, sleeping, exiting |
| `io.gleam` | Styled output and the glitzer progress line |
| `esgleam/` | Vendored (Apache-2.0, forked) esbuild platform detection and tarball extraction only; do not add unrelated code here |

When changing behavior, change the pure function and its test first; the shell
only reads, writes and calls it.

## Non-negotiables from how this got built

- **The user's module exports `handle` on both targets.** JavaScript:
  `fn(Request(conversation.RequestBody)) -> Response(conversation.ResponseBody)`
  or a `Promise` of that. Erlang: `fn(wisp.Request) -> wisp.Response`. There is
  no `handler` fallback, no user-written `start/0` and no direct
  `afterglow.serve`. `giolt build` checks this from the package interface, and the
  worker shim still checks at request time.
- **The generated `start/0` calls the handler through a lambda**
  (`afterglow.serve(fn(req) { user.handle(req) })`). Passing `user.handle` by
  reference compiles to an external fun literal; glowvm's packer did not
  follow those and silently dropped the user's modules. The lambda keeps the
  call a plain remote call, which afterglow's reachability analysis follows.
  A test covers this; keep it.
- **afterglow builds happen in a generated package**, `build/.giolt/afterglow`,
  that depends on the user's project by path, so the user does not need
  `afterglow` as a direct dependency. The `afterglow` Hex package carries the
  native compiler for each platform, the runtime and the Worker entry in
  `priv/`; Binaryen comes from the `binaryen` npm package and runs on the same
  runtime as the CLI. The user's machine needs Erlang/OTP and rebar3, and
  `giolt build` says so before doing any work. Gleam resolves a path
  dependency's own dependencies afresh and ignores a copied `manifest.toml`, so
  the generated `gleam.toml` pins with `==` each Hex package the user's
  manifest locks that their `[dependencies]` reach. Dev dependencies stay out,
  because a direct dependency of the build package is compiled on every build.
- **`bundle.run` never runs `gleam build`; `commands.gleam` does.** `bundle`
  takes a plain path to a JS file and only reads it. Don't make it shell out.
- **`dev` rebuilds in-process.** Every build step is a subprocess (gleam,
  esbuild, the `prebuild` hook), so there is no stale-module problem and no
  supervisor. The dev server reloads the worker from a per-version copy of the
  bundle, because Bun ignores the query string when caching ES modules.
- **`bundle.run` only checks that the entry file exists, not its contents.**
  Don't reintroduce static export-shape parsing of the compiled JS.
- **The bundle has almost no configuration surface.** It is always minified,
  tree-shaken ESM for the node platform. `esbuild_args` is one plain
  pass-through list appended after the fixed flags (later flags win). Don't turn
  it into named options.
- **`artifact` makes a static-only site.** With the key (or `deploy --artifact`)
  set, `build` runs only `prebuild` and checks the directory, `deploy` uploads
  every file in it as an asset with no worker module, and `dev` serves it with no
  worker. There is no `handle` check or bundling, and it works for either target.
- **Hooks are command strings.** `prebuild` runs through the shell before every
  build, including each `dev` rebuild. There is no closure API.
- **No env-var handling beyond the API.** `GIOLT_TOKEN` (authentication) and
  `GIOLT_API_URL` (overrides `api_url`) are read in `commands.gleam` and passed
  to `deploy.route` and, for the account commands, `credentials.resolve`. `XDG_CONFIG_HOME` and
  `APPDATA` only locate `credentials.json`. No `.env` loading, no
  `PUBLIC_`/`PRIVATE_` inlining.
- **No glob or ignore matching in `dev`.** `watch` takes directories.
- **Node 20+ and Bun are the supported runtimes** (`gleam run -m giolt` and
  `gleam run --runtime bun -m giolt`); Deno is not supported. On Erlang the
  CLI only re-runs itself on JavaScript; don't port commands to the BEAM.
  Erlang module names are global, so Erlang FFI files are named `giolt_ffi_*.erl`. Node 20 is the
  floor because `fs.watch` is only recursive on Linux from there. The Erlang
  target's output is only `app.wasm`, `index.mjs`, `host.mjs` and `static/`.
- **Comments are minimal.** Almost no doc comments in `src/`. Let names and
  types carry the meaning; the few comments that exist are load-bearing.
- **The runtime package `afterglow` is declared as a Hex range** in the
  generated `gleam.toml` (`internal/afterglow.gleam`). `giolt deploy` uploads the
  Erlang target's output like a JavaScript build: afterglow's `index.mjs` is the
  entry the platform wraps.
- **The platform's capabilities arrive as `fetch`'s second argument.** The
  shim keeps them under `Symbol.for("giolt.platform")` and never reads `env`.
  The platform passes one frozen object to every request, so a request never
  sees another's through that global. afterglow's entry passes only the
  object's string values to the Wasm, as vars, so a capability that is a
  function cannot reach an Erlang app until afterglow has host imports for it.

## Vendored code

`src/giolt/internal/esgleam/` is a trimmed fork of
[Enderchief/esgleam](https://github.com/Enderchief/esgleam) (Apache-2.0, see
`NOTICE`/`LICENSE` in that directory): esbuild platform detection
(`esgleam/mod/platform.gleam`) and tarball extraction (`streaming_tar.mjs`).
Keep the `// Modified from Enderchief/esgleam...` attribution line at the top
of files taken from there.

## npm package

`just build-npm` bundles `npm/bin.mjs` (which calls the compiled `main`) into
`dist/giolt.mjs` and writes `dist/package.json` from `npm/package.json` with
the version in `gleam.toml`. Publish `./dist`. `ffi_npm.mjs` imports
`esgleam/streaming_tar.mjs` statically, so the bundle contains it;
`dist/esgleam/` only carries its LICENSE and NOTICE.

## FFI conventions

All `.mjs` files live beside the Gleam module that declares their
`@external`, and are referenced as `"./file.mjs"`. To import the generated
prelude (`Ok`/`Error`) from `src/giolt/internal/X.mjs`, use `"../../gleam.mjs"`:
Gleam compiles this package's modules to
`build/dev/javascript/giolt/giolt/...`, so a file two segments below `src/`
needs two `../`, and one in `internal/esgleam/` needs three.

## Testing

`gleam test --target javascript`, or `just test`. Tests in `test/` target the
pure functions above directly. Real runs need a scratch Gleam project that
depends on this repo by path as a dev dependency.

CI (`.github/workflows/test.yml`) runs `gleam format --check src test` and
`gleam test` on Node 20, Node 22 and Bun on every push and PR, including
feature branches. Keep it that way, so "both runtimes work" stays checked.
