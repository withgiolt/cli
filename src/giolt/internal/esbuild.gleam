pub type Plan {
  Plan(entry: String, outfile: String, additional_args: List(String))
}

pub fn flags(plan: Plan) -> List(String) {
  [
    plan.entry,
    "--bundle",
    "--format=esm",
    "--platform=node",
    "--minify",
    "--tree-shaking=true",
    "--outfile=" <> plan.outfile,
    ..plan.additional_args
  ]
}

// One directory per version, so changing the version installs it afresh.
pub fn install_dir() -> String {
  "./build/dev/bin/esbuild-" <> version
}

// The Windows package keeps the binary at its root, the others in bin/.
pub fn package_file(exe_name: String) -> String {
  case exe_name {
    "esbuild.exe" -> exe_name
    _ -> "bin/" <> exe_name
  }
}

pub fn exe_path(exe_name: String) -> String {
  install_dir() <> "/" <> package_file(exe_name)
}

pub fn tarball_url(package: String) -> String {
  "https://registry.npmjs.org/@esbuild/"
  <> package
  <> "/-/"
  <> package
  <> "-"
  <> version
  <> ".tgz"
}

pub const version = "0.28.2"
