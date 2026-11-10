import giolt/internal/bundle
import gleam/string

pub fn describe_error_entry_file_not_found_test() {
  let message =
    bundle.describe_error(bundle.EntryFileNotFound(
      "./build/dev/javascript/app/app.mjs",
    ))

  assert string.contains(message, "./build/dev/javascript/app/app.mjs")
}

pub fn describe_error_static_dir_not_found_test() {
  let message = bundle.describe_error(bundle.StaticDirNotFound("./public"))

  assert string.contains(message, "./public")
}

pub fn is_unsafe_outdir_current_dir_test() {
  assert bundle.is_unsafe_outdir(".")
  assert bundle.is_unsafe_outdir("./")
  assert bundle.is_unsafe_outdir("")
  assert bundle.is_unsafe_outdir("..")
  assert bundle.is_unsafe_outdir("/")
}

pub fn is_unsafe_outdir_trims_whitespace_test() {
  assert bundle.is_unsafe_outdir(" . ")
}

pub fn is_unsafe_outdir_allows_real_dirs_test() {
  assert !bundle.is_unsafe_outdir("./dist")
  assert !bundle.is_unsafe_outdir("dist")
  assert !bundle.is_unsafe_outdir("../dist")
}

pub fn describe_error_unsafe_outdir_test() {
  let message = bundle.describe_error(bundle.UnsafeOutdir("."))

  assert string.contains(message, "./dist")
}

pub fn outdir_contains_entry_true_test() {
  assert bundle.outdir_contains_entry(
    outdir: "./dist",
    entry: "./dist/index.mjs",
  )
}

pub fn outdir_contains_entry_nested_test() {
  assert bundle.outdir_contains_entry(
    outdir: "./dist",
    entry: "./dist/workers/index.mjs",
  )
}

pub fn outdir_contains_entry_false_test() {
  assert !bundle.outdir_contains_entry(
    outdir: "./dist",
    entry: "./build/dev/javascript/app/app.mjs",
  )
}

pub fn outdir_contains_entry_sibling_prefix_false_test() {
  assert !bundle.outdir_contains_entry(
    outdir: "./dist",
    entry: "./dist-static/index.mjs",
  )
}

pub fn describe_error_entry_inside_outdir_test() {
  let message =
    bundle.describe_error(bundle.EntryInsideOutdir(
      entry: "./dist/index.mjs",
      outdir: "./dist",
    ))

  assert string.contains(message, "./dist/index.mjs")
  assert string.contains(message, "./dist")
}
