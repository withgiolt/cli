import { chmod, mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { Buffer } from "node:buffer";
import { Ok, Error as GleamError } from "../../gleam.mjs";
import { entries } from "./esgleam/streaming_tar.mjs";

// Downloads an npm tarball and writes only the listed files (paths inside the
// package, such as "bin/wasm-opt") under directory.
export async function install_from_npm(url, directory, files) {
  const wanted = new Set(files.toArray());
  try {
    const response = await fetch(url);
    if (!response.ok) return new GleamError(`Downloading ${url} failed: HTTP ${response.status}`);

    const stream = response.body.pipeThrough(new DecompressionStream("gzip"));
    for await (const entry of entries(stream)) {
      const name = entry.name.replace(/^package\//, "");
      // The reader only moves to the next entry once this one's body is consumed.
      if (!wanted.has(name)) {
        await entry.skip();
        continue;
      }
      const path = `${directory}/${name}`;
      await mkdir(dirname(path), { recursive: true });
      await writeFile(path, Buffer.from(await entry.arrayBuffer()));
      wanted.delete(name);
      if (wanted.size === 0) break;
    }
  } catch (error) {
    return new GleamError(`Downloading ${url} failed: ${error.message}`);
  }

  if (wanted.size > 0) {
    return new GleamError(`${url} did not contain ${[...wanted].join(", ")}`);
  }
  return new Ok(undefined);
}

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
