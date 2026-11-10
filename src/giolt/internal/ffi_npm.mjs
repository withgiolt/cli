import { mkdir, rename, rm, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { Buffer } from "node:buffer";
import { Ok, Error as GleamError } from "../../gleam.mjs";
import { entries } from "./esgleam/streaming_tar.mjs";

// Writes the listed files (paths inside the package, such as "bin/wasm-opt")
// to a sibling directory and renames it into place only once all of them have
// arrived, so an interrupted download never leaves a directory that looks
// installed.
export async function install(url, relative_directory, files) {
  // Bun 1.4 on Windows silently skips fs.promises.rm for a path starting
  // with "./", so the paths are made absolute first.
  const directory = resolve(relative_directory);
  const wanted = new Set(files.toArray());
  const partial = `${directory}.partial`;
  // Stops the download once the last wanted file is read.
  const download = new AbortController();

  try {
    await rm(partial, { recursive: true, force: true });
    const response = await fetch(url, { signal: download.signal });
    if (!response.ok) {
      return new GleamError(`Downloading ${url} failed: HTTP ${response.status}`);
    }

    const stream = response.body.pipeThrough(new DecompressionStream("gzip"));
    for await (const entry of entries(stream)) {
      const name = entry.name.replace(/^package\//, "");
      // The reader only moves to the next entry once this one's body is consumed.
      if (!wanted.has(name)) {
        await entry.skip();
        continue;
      }
      const path = `${partial}/${name}`;
      await mkdir(dirname(path), { recursive: true });
      await writeFile(path, Buffer.from(await entry.arrayBuffer()), { mode: 0o755 });
      wanted.delete(name);
      if (wanted.size === 0) break;
    }

    if (wanted.size > 0) {
      await rm(partial, { recursive: true, force: true });
      return new GleamError(`${url} did not contain ${[...wanted].join(", ")}`);
    }

    await rm(directory, { recursive: true, force: true });
    await rename(partial, directory);
    return new Ok(undefined);
  } catch (error) {
    await rm(partial, { recursive: true, force: true }).catch(() => {});
    return new GleamError(`Downloading ${url} failed: ${error.message}`);
  } finally {
    download.abort();
  }
}
