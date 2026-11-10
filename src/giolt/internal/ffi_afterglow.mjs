import { chmod } from "node:fs/promises";
import { Ok, Error as GleamError } from "../../gleam.mjs";

// Hex tarballs don't keep file modes, so the compiler from the afterglow package
// arrives without its executable bit on Linux and macOS.
export async function make_executable(path) {
  try {
    await chmod(path, 0o755);
    return new Ok(undefined);
  } catch (error) {
    return new GleamError(`Could not make ${path} executable: ${error.message}`);
  }
}
