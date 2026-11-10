import { spawn } from "node:child_process";
import { Ok, Error as GleamError } from "../../gleam.mjs";

export function exec(command, args) {
  const child = spawn(command, args.toArray(), { cwd: ".", stdio: "inherit" });

  return new Promise((resolve) => {
    child.on("error", (error) => resolve(new GleamError(error.message)));
    child.on("close", (status, signal) => {
      resolve(
        status === 0
          ? new Ok(undefined)
          : new GleamError(
              `esbuild exited with status ${status ?? `signal ${signal}`}`,
            ),
      );
    });
  });
}
