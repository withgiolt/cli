import { Ok, Error as GleamError } from "../../gleam.mjs";

export async function transmit(req, method, url) {
  let response;
  try {
    response = await fetch(url, {
      method,
      headers: req.headers.toArray(),
      body: method === "GET" || method === "HEAD" ? undefined : req.body,
    });
  } catch {
    return new GleamError(undefined);
  }

  try {
    return new Ok([response.status, new Ok(await response.text())]);
  } catch {
    return new Ok([response.status, new GleamError(undefined)]);
  }
}
