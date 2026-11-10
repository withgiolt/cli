import { createServer } from "node:http";
import { readFileSync } from "node:fs";

// Serves a tarball whole, cut in half, or not at all, on a free local port.
export function serve(fixture) {
  const tarball = readFileSync(fixture);
  const server = createServer((request, response) => {
    if (request.url === "/package.tgz") {
      response.end(tarball);
    } else if (request.url === "/truncated.tgz") {
      response.end(tarball.subarray(0, Math.floor(tarball.length / 2)));
    } else {
      response.statusCode = 404;
      response.end();
    }
  });

  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const base = `http://127.0.0.1:${server.address().port}`;
      resolve([base, () => server.close()]);
    });
  });
}
