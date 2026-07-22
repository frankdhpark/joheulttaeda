import { createServer } from "node:http";

const DEFAULT_PORT = 8787;
const MAX_REQUEST_BYTES = 16 * 1024;
const META_TIMEOUT_MS = 12_000;

export function normalizeInstagramURL(rawValue) {
  if (typeof rawValue !== "string" || rawValue.length > 2_048) {
    return null;
  }

  let url;
  try {
    url = new URL(rawValue);
  } catch {
    return null;
  }

  const host = url.hostname.toLowerCase();
  if (url.protocol !== "https:" || !["instagram.com", "www.instagram.com"].includes(host)) {
    return null;
  }

  const pathParts = url.pathname.split("/").filter(Boolean);
  const supportedKinds = new Set(["p", "reel", "reels", "tv"]);
  if (pathParts.length < 2 || !supportedKinds.has(pathParts[0].toLowerCase())) {
    return null;
  }

  url.hostname = "www.instagram.com";
  url.search = "";
  url.hash = "";
  url.pathname = `/${pathParts[0].toLowerCase()}/${pathParts[1]}/`;
  return url;
}

function sendJSON(response, statusCode, body) {
  const data = Buffer.from(JSON.stringify(body));
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": data.byteLength,
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  });
  response.end(data);
}

async function readJSON(request) {
  const chunks = [];
  let byteCount = 0;

  for await (const chunk of request) {
    byteCount += chunk.length;
    if (byteCount > MAX_REQUEST_BYTES) {
      const error = new Error("Request body is too large.");
      error.statusCode = 413;
      throw error;
    }
    chunks.push(chunk);
  }

  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    const error = new Error("Request body must be valid JSON.");
    error.statusCode = 400;
    throw error;
  }
}

async function fetchEmbedHTML({ sourceURL, accessToken, graphAPIVersion, fetchImpl }) {
  const versionPath = graphAPIVersion ? `/${graphAPIVersion}` : "";
  const endpoint = new URL(`https://graph.facebook.com${versionPath}/instagram_oembed`);
  endpoint.searchParams.set("url", sourceURL.href);
  endpoint.searchParams.set("maxwidth", "640");

  const metaResponse = await fetchImpl(endpoint, {
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    signal: AbortSignal.timeout(META_TIMEOUT_MS),
  });

  const responseBody = await metaResponse.json().catch(() => null);
  const html = responseBody?.html;
  if (!metaResponse.ok || typeof html !== "string" || html.trim().length === 0) {
    const metaCode = responseBody?.error?.code;
    console.error("Instagram oEmbed request failed", {
      status: metaResponse.status,
      metaCode: typeof metaCode === "number" ? metaCode : undefined,
    });
    const error = new Error(
      metaResponse.status === 400 || metaResponse.status === 403
        ? "이 Meta 앱에는 해당 게시물을 표시할 권한이 없습니다."
        : "Instagram에서 플레이어를 가져오지 못했습니다."
    );
    error.statusCode = metaResponse.status === 429 ? 429 : 502;
    throw error;
  }

  if (Buffer.byteLength(html, "utf8") > 1_000_000) {
    const error = new Error("Instagram 플레이어 응답이 너무 큽니다.");
    error.statusCode = 502;
    throw error;
  }
  return html;
}

export function createInstagramOEmbedServer({
  accessToken,
  graphAPIVersion = "",
  apiKey = "",
  fetchImpl = fetch,
}) {
  if (!accessToken) {
    throw new Error("META_OEMBED_ACCESS_TOKEN is required.");
  }
  if (graphAPIVersion && !/^v\d+\.\d+$/.test(graphAPIVersion)) {
    throw new Error("META_GRAPH_API_VERSION must look like v21.0.");
  }

  return createServer(async (request, response) => {
    const requestURL = new URL(request.url ?? "/", "http://localhost");

    if (request.method === "GET" && requestURL.pathname === "/health") {
      sendJSON(response, 200, { status: "ok" });
      return;
    }

    if (request.method !== "POST" || requestURL.pathname !== "/instagram/oembed") {
      sendJSON(response, 404, { message: "Not found." });
      return;
    }

    if (apiKey && request.headers["x-api-key"] !== apiKey) {
      sendJSON(response, 401, { message: "인증되지 않은 요청입니다." });
      return;
    }

    try {
      const body = await readJSON(request);
      const sourceURL = normalizeInstagramURL(body?.sourceURL);
      if (!sourceURL) {
        sendJSON(response, 400, { message: "지원하지 않는 Instagram 주소입니다." });
        return;
      }

      const html = await fetchEmbedHTML({
        sourceURL,
        accessToken,
        graphAPIVersion,
        fetchImpl,
      });
      sendJSON(response, 200, { html });
    } catch (error) {
      if (error?.name === "TimeoutError") {
        sendJSON(response, 504, { message: "Instagram 응답 시간이 초과되었습니다." });
        return;
      }

      const statusCode = Number.isInteger(error?.statusCode) ? error.statusCode : 500;
      const publicMessage = statusCode >= 500
        ? error?.message ?? "플레이어를 불러오지 못했습니다."
        : error?.message ?? "요청을 처리할 수 없습니다.";
      sendJSON(response, statusCode, { message: publicMessage });
    }
  });
}

function startFromEnvironment() {
  const server = createInstagramOEmbedServer({
    accessToken: process.env.META_OEMBED_ACCESS_TOKEN?.trim(),
    graphAPIVersion: process.env.META_GRAPH_API_VERSION?.trim(),
    apiKey: process.env.IDEA_EMBED_API_KEY?.trim(),
  });
  const port = Number.parseInt(process.env.PORT ?? String(DEFAULT_PORT), 10);
  const host = process.env.HOST?.trim() || "127.0.0.1";

  server.listen(port, host, () => {
    console.log(`Instagram oEmbed backend listening on http://${host}:${port}`);
  });
}

if (process.argv[1] && import.meta.url === new URL(process.argv[1], "file:").href) {
  startFromEnvironment();
}
