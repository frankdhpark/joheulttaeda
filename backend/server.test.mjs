import assert from "node:assert/strict";
import { afterEach, test } from "node:test";
import { createInstagramOEmbedServer, normalizeInstagramURL } from "./server.mjs";

const activeServers = [];

afterEach(async () => {
  await Promise.all(activeServers.splice(0).map(
    (server) => new Promise((resolve) => server.close(resolve))
  ));
});

test("normalizes supported Instagram post URLs", () => {
  assert.equal(
    normalizeInstagramURL("https://instagram.com/reel/ABC123/?utm_source=share")?.href,
    "https://www.instagram.com/reel/ABC123/"
  );
  assert.equal(
    normalizeInstagramURL("https://www.instagram.com/p/POST123/")?.href,
    "https://www.instagram.com/p/POST123/"
  );
});

test("rejects non-Instagram and unsupported URLs", () => {
  assert.equal(normalizeInstagramURL("https://example.com/reel/ABC123/"), null);
  assert.equal(normalizeInstagramURL("https://instagram.com/accounts/login/"), null);
  assert.equal(normalizeInstagramURL("http://instagram.com/reel/ABC123/"), null);
});

test("returns Meta embed HTML without persisting it", async () => {
  const fetchImpl = async (url, options) => {
    assert.equal(url.hostname, "graph.facebook.com");
    assert.equal(url.pathname, "/v21.0/instagram_oembed");
    assert.equal(url.searchParams.get("url"), "https://www.instagram.com/reel/ABC123/");
    assert.equal(options.headers.Authorization, "Bearer test-token");
    return Response.json({ html: "<blockquote>embed</blockquote>" });
  };
  const server = createInstagramOEmbedServer({
    accessToken: "test-token",
    graphAPIVersion: "v21.0",
    fetchImpl,
  });
  activeServers.push(server);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();

  const response = await fetch(`http://127.0.0.1:${port}/instagram/oembed`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sourceURL: "https://instagram.com/reel/ABC123/?utm_source=share" }),
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { html: "<blockquote>embed</blockquote>" });
  assert.equal(response.headers.get("cache-control"), "no-store");
});

test("requires the optional app API key when configured", async () => {
  const server = createInstagramOEmbedServer({
    accessToken: "test-token",
    apiKey: "expected-key",
    fetchImpl: async () => Response.json({ html: "unused" }),
  });
  activeServers.push(server);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();

  const response = await fetch(`http://127.0.0.1:${port}/instagram/oembed`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sourceURL: "https://instagram.com/reel/ABC123/" }),
  });

  assert.equal(response.status, 401);
});
