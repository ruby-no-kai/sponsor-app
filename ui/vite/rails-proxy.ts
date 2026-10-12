import { readFile } from "node:fs/promises";
import { request as httpRequest } from "node:http";
import { request as httpsRequest } from "node:https";
import type {
  IncomingHttpHeaders,
  IncomingMessage,
  OutgoingHttpHeaders,
  ServerResponse,
} from "node:http";
import { join } from "node:path";
import { pipeline } from "node:stream";
import type { Connect, Plugin } from "vite";
import { isSpaPathname } from "../src/routes/paths.ts";

// Marks a request this proxy sent to Rails. Seeing it come back means Rails' URL points here.
export const LOOP_HEADER = "x-sponsor-app-ui-proxy";

export type Destination = "vite" | "spa" | "rails" | "loop";

type RequestLike = Pick<IncomingMessage, "method" | "url" | "headers">;

// Where the dev server sends a request: Vite's own files live under base, an SPA navigation gets
// index.html, and everything else is Rails'.
export function destinationOf(req: RequestLike, base: string): Destination {
  if (req.headers[LOOP_HEADER] !== undefined) return "loop";

  const { pathname } = new URL(req.url ?? "/", "http://dev.invalid");
  if (pathname.startsWith(base)) return "vite";
  if (isNavigation(req) && isSpaPathname(pathname)) return "spa";
  return "rails";
}

// Sec-Fetch-Dest tells a page load from fetch() or a subresource. Accept stands in for clients
// that do not send it.
function isNavigation(req: RequestLike): boolean {
  if (req.method !== "GET" && req.method !== "HEAD") return false;

  const dest = req.headers["sec-fetch-dest"];
  if (dest !== undefined) return dest === "document";
  return (req.headers.accept ?? "").includes("text/html");
}

// RFC 9110 section 7.6.1: these describe one connection and are never forwarded.
const HOP_BY_HOP = new Set([
  "connection",
  "keep-alive",
  "proxy-connection",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
]);

function forwardableHeaders(headers: IncomingHttpHeaders): OutgoingHttpHeaders {
  const listed = new Set(
    String(headers.connection ?? "")
      .split(",")
      .map((name) => name.trim().toLowerCase())
      .filter((name) => name !== ""),
  );
  const result: OutgoingHttpHeaders = {};
  for (const [name, value] of Object.entries(headers)) {
    if (value === undefined || HOP_BY_HOP.has(name) || listed.has(name)) continue;
    result[name] = value;
  }
  return result;
}

// Host passes through unchanged, so Rails builds URLs and checks Origin against the host the
// browser used, and its cookies stay on that host. X-Forwarded-* from trustless pass through too.
export function proxyToRails(req: IncomingMessage, res: ServerResponse, railsUrl: URL): void {
  const request = railsUrl.protocol === "https:" ? httpsRequest : httpRequest;
  const upstream = request(
    {
      protocol: railsUrl.protocol,
      hostname: railsUrl.hostname,
      port: railsUrl.port,
      method: req.method,
      path: req.url,
      headers: { ...forwardableHeaders(req.headers), [LOOP_HEADER]: "1" },
    },
    (upstreamRes) => {
      res.writeHead(
        upstreamRes.statusCode ?? 502,
        upstreamRes.statusMessage,
        forwardableHeaders(upstreamRes.headers),
      );
      // Tears down the browser's response when Rails drops the connection mid-body, and vice versa.
      pipeline(upstreamRes, res, () => {});
    },
  );
  upstream.on("error", (error) => {
    if (res.headersSent) {
      res.destroy(error);
      return;
    }
    res.writeHead(502, { "content-type": "text/plain; charset=utf-8" });
    res.end(`Rails is not reachable at ${railsUrl.origin}: ${error.message}\n`);
  });
  res.on("close", () => {
    if (!res.writableFinished) upstream.destroy();
  });
  req.pipe(upstream);
}

export type RailsProxyOptions = {
  railsUrl: URL;
  base: string;
  renderIndexHtml: (url: string) => Promise<string>;
};

export function railsProxyMiddleware(options: RailsProxyOptions): Connect.NextHandleFunction {
  return (req, res, next) => {
    switch (destinationOf(req, options.base)) {
      case "vite":
        next();
        return;
      case "loop":
        res.writeHead(508, { "content-type": "text/plain; charset=utf-8" });
        res.end(
          `Loop detected: SPONSOR_APP_RAILS_URL (${options.railsUrl.origin}) leads back to this server.\n`,
        );
        return;
      case "spa":
        options.renderIndexHtml(req.url ?? "/").then(
          (html) => {
            res.writeHead(200, {
              "content-type": "text/html; charset=utf-8",
              "cache-control": "no-cache",
            });
            res.end(req.method === "HEAD" ? undefined : html);
          },
          (error: unknown) => next(error),
        );
        return;
      case "rails":
        proxyToRails(req, res, options.railsUrl);
        return;
    }
  };
}

// Development only: makes the Vite server the single origin for the SPA and the Rails app. Vite's
// host check runs before this middleware, so it applies to proxied requests too.
export function railsProxy(railsUrl: string): Plugin {
  return {
    name: "sponsor-app:rails-proxy",
    apply: "serve",
    configureServer(server) {
      const indexHtmlPath = join(server.config.root, "index.html");
      server.middlewares.use(
        railsProxyMiddleware({
          railsUrl: new URL(railsUrl),
          base: server.config.base,
          renderIndexHtml: async (url) =>
            server.transformIndexHtml(url, await readFile(indexHtmlPath, "utf8")),
        }),
      );
    },
  };
}
