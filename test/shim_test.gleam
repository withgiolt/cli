import giolt/internal/shim
import gleam/string

pub fn render_substitutes_entry_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert string.contains(
    rendered,
    "import * as app from \"/home/user/app/build/dev/javascript/app/app.mjs\";",
  )
}

pub fn render_has_no_leftover_placeholder_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert !string.contains(rendered, "{entry}")
}

pub fn render_imports_conversation_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert string.contains(rendered, "conversation/conversation.mjs")
}

pub fn render_calls_handle_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert string.contains(rendered, "app.handle(req)")
}

pub fn render_guards_missing_handle_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert string.contains(rendered, "typeof app.handle !== \"function\"")
}

pub fn render_rejects_non_object_body_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert string.contains(rendered, "typeof body !== \"object\"")
}

pub fn render_checks_body_before_converting_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  let assert Ok(#(before, _)) =
    string.split_once(rendered, "conversation.to_js_response")
  assert string.contains(before, "typeof body !== \"object\"")
}

pub fn render_missing_export_message_names_rename_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert string.contains(rendered, "does not export a `handle` function")
  assert string.contains(rendered, "renamed from `handler` to `handle`")
}

pub fn render_has_no_handler_fallback_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert !string.contains(rendered, "app.handler")
}

pub fn render_escapes_windows_path_backslashes_test() {
  let rendered = shim.render("C:\\Users\\me\\app\\app.mjs")

  assert string.contains(
    rendered,
    "import * as app from \"C:\\\\Users\\\\me\\\\app\\\\app.mjs\";",
  )
}

pub fn render_escapes_quotes_in_path_test() {
  let rendered = shim.render("/home/we\"ird/app.mjs")

  assert string.contains(rendered, "from \"/home/we\\\"ird/app.mjs\";")
}

// The platform hands its capability object to `fetch` as the second
// argument. The shim keeps it under a registered symbol, which a library in
// the same bundle can read without importing the shim.
pub fn render_keeps_the_platform_argument_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert string.contains(rendered, "async fetch(request, platform, _ctx)")
  assert string.contains(
    rendered,
    "globalThis[Symbol.for(\"giolt.platform\")] = platform;",
  )
}
