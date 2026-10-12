import assert from "node:assert/strict";
import { createServer, request } from "node:http";
import type { IncomingHttpHeaders, IncomingMessage, RequestListener, Server } from "node:http";
import type { AddressInfo } from "node:net";
import { after, before, describe, it } from "node:test";
import { LOOP_HEADER, destinationOf, railsProxyMiddleware } from "./rails-proxy.ts";

const BASE = "/_ui/";

function req(method: string, url: string, headers: IncomingHttpHeaders = {}) {
  return { method, url, headers };
}

const page = { "sec-fetch-dest": "document", accept: "text/html,application/xhtml+xml" };

describe("destinationOf", () => {
  it("renders the SPA for a page load of an SPA path", () => {
    assert.equal(destinationOf(req("GET", "/admin", page), BASE), "spa");
    assert.equal(
      destinationOf(req("GET", "/admin/conferences/rubykaigi2048?tab=plans", page), BASE),
      "spa",
    );
    assert.equal(destinationOf(req("HEAD", "/admin/conferences", page), BASE), "spa");
  });

  it("falls back to Accept when Sec-Fetch-Dest is absent", () => {
    assert.equal(
      destinationOf(req("GET", "/admin/conferences", { accept: "text/html" }), BASE),
      "spa",
    );
    assert.equal(
      destinationOf(req("GET", "/admin/conferences", { accept: "application/json" }), BASE),
      "rails",
    );
  });

  it("proxies fetches and subresources of SPA paths", () => {
    const fetchHeaders = { "sec-fetch-dest": "empty", accept: "text/html" };
    assert.equal(destinationOf(req("GET", "/admin/conferences", fetchHeaders), BASE), "rails");
  });

  it("proxies other methods", () => {
    assert.equal(destinationOf(req("POST", "/admin/conferences", page), BASE), "rails");
  });

  it("proxies paths the SPA does not render", () => {
    for (const url of [
      "/",
      "/admin/conferences/rubykaigi2048/plans",
      "/admin/conferences/rubykaigi2048/sponsors_yml",
      "/admin/session/new?back_to=%2Fadmin",
      "/auth/github/callback",
      "/conferences/rubykaigi2048/sponsorship",
      "/letter_opener",
      "/vite-dev/@vite/client",
    ]) {
      assert.equal(destinationOf(req("GET", url, page), BASE), "rails", url);
    }
  });

  it("proxies Connect RPCs", () => {
    const url =
      "/rubykaigi.sponsor_app.AdminService/GetViewer?connect=v1&encoding=json&message=%7B%7D";
    assert.equal(destinationOf(req("GET", url, { "sec-fetch-dest": "empty" }), BASE), "rails");
    assert.equal(
      destinationOf(req("POST", "/rubykaigi.sponsor_app.AdminService/SignOut", {}), BASE),
      "rails",
    );
  });

  it("leaves Vite's own paths to Vite", () => {
    assert.equal(destinationOf(req("GET", "/_ui/@vite/client", {}), BASE), "vite");
    assert.equal(destinationOf(req("GET", "/_ui/src/main.tsx", page), BASE), "vite");
  });

  it("detects a request it already proxied", () => {
    assert.equal(
      destinationOf(req("GET", "/admin", { ...page, [LOOP_HEADER]: "1" }), BASE),
      "loop",
    );
  });
});

type Response = { status: number; headers: IncomingHttpHeaders; body: string };

function send(
  server: Server,
  method: string,
  path: string,
  headers: Record<string, string> = {},
  body?: string,
) {
  const { port } = server.address() as AddressInfo;
  return new Promise<Response>((resolve, reject) => {
    const outgoing = request({ host: "127.0.0.1", port, method, path, headers }, (res) => {
      let data = "";
      res.setEncoding("utf8");
      res.on("data", (chunk: string) => (data += chunk));
      res.on("end", () =>
        resolve({ status: res.statusCode ?? 0, headers: res.headers, body: data }),
      );
    });
    outgoing.on("error", reject);
    outgoing.end(body);
  });
}

function listen(handler: RequestListener): Promise<Server> {
  return new Promise((resolve) => {
    const server = createServer(handler);
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function close(server: Server): Promise<void> {
  return new Promise((resolve) => server.close(() => resolve()));
}

function readBody(incoming: IncomingMessage): Promise<string> {
  return new Promise((resolve) => {
    let data = "";
    incoming.setEncoding("utf8");
    incoming.on("data", (chunk: string) => (data += chunk));
    incoming.on("end", () => resolve(data));
  });
}

describe("railsProxyMiddleware", () => {
  let rails: Server;
  let proxy: Server;
  let seen: { method?: string; url?: string; headers: IncomingHttpHeaders; body: string }[] = [];

  before(async () => {
    rails = await listen(async (incoming, res) => {
      seen.push({
        method: incoming.method,
        url: incoming.url,
        headers: incoming.headers,
        body: await readBody(incoming),
      });
      if (incoming.url === "/admin/session/backdoor") {
        res.writeHead(302, {
          location: "http://sponsor-app.localhost:1355/admin",
          "set-cookie": ["a=1", "b=2"],
        });
        res.end();
        return;
      }
      res.writeHead(200, { "content-type": "text/plain" });
      res.end(`rails ${incoming.method} ${incoming.url}`);
    });
    const { port } = rails.address() as AddressInfo;
    const middleware = railsProxyMiddleware({
      railsUrl: new URL(`http://127.0.0.1:${port}`),
      base: BASE,
      renderIndexHtml: async (url) => `<html>spa ${url}</html>`,
    });
    proxy = await listen((incoming, res) =>
      middleware(incoming, res, () => {
        res.writeHead(404);
        res.end("vite");
      }),
    );
  });

  after(async () => {
    await close(proxy);
    await close(rails);
  });

  it("serves index.html for an SPA navigation", async () => {
    const res = await send(proxy, "GET", "/admin/conferences", page);

    assert.equal(res.status, 200);
    assert.match(res.headers["content-type"] ?? "", /^text\/html/);
    assert.equal(res.body, "<html>spa /admin/conferences</html>");
  });

  it("answers HEAD without a body", async () => {
    const res = await send(proxy, "HEAD", "/admin", page);

    assert.equal(res.status, 200);
    assert.equal(res.body, "");
  });

  it("passes Vite's paths on", async () => {
    assert.equal((await send(proxy, "GET", "/_ui/@vite/client")).body, "vite");
  });

  it("forwards everything else to Rails with the browser's Host and the loop marker", async () => {
    seen = [];
    const res = await send(
      proxy,
      "POST",
      "/admin/session/backdoor",
      {
        host: "sponsor-app.localhost:1355",
        "content-type": "application/x-www-form-urlencoded",
        "x-forwarded-proto": "http",
        connection: "keep-alive, x-hop",
        "x-hop": "dropped",
      },
      "login=sorah",
    );

    assert.equal(res.status, 302);
    assert.equal(res.headers.location, "http://sponsor-app.localhost:1355/admin");
    assert.deepEqual(res.headers["set-cookie"], ["a=1", "b=2"]);

    const [forwarded] = seen;
    assert.ok(forwarded);
    assert.equal(forwarded.method, "POST");
    assert.equal(forwarded.body, "login=sorah");
    assert.equal(forwarded.headers.host, "sponsor-app.localhost:1355");
    assert.equal(forwarded.headers["x-forwarded-proto"], "http");
    assert.equal(forwarded.headers[LOOP_HEADER], "1");
    assert.equal(forwarded.headers["x-hop"], undefined);
  });

  it("keeps the query string", async () => {
    const res = await send(
      proxy,
      "GET",
      "/rubykaigi.sponsor_app.AdminService/GetViewer?connect=v1&message=%7B%7D",
    );

    assert.equal(
      res.body,
      "rails GET /rubykaigi.sponsor_app.AdminService/GetViewer?connect=v1&message=%7B%7D",
    );
  });

  it("answers 508 to a request it sent itself", async () => {
    seen = [];
    const res = await send(proxy, "GET", "/admin", { ...page, [LOOP_HEADER]: "1" });

    assert.equal(res.status, 508);
    assert.equal(seen.length, 0);
  });

  it("answers 502 while Rails is down", async () => {
    const down = await listen(() => {});
    const { port } = down.address() as AddressInfo;
    await close(down);
    const middleware = railsProxyMiddleware({
      railsUrl: new URL(`http://127.0.0.1:${port}`),
      base: BASE,
      renderIndexHtml: async () => "",
    });
    const orphan = await listen((incoming, res) => middleware(incoming, res, () => {}));

    const res = await send(orphan, "GET", "/admin/session/new");
    await close(orphan);

    assert.equal(res.status, 502);
    assert.match(res.body, /Rails is not reachable/);
  });

  it(
    "closes the response when Rails drops the connection mid-body",
    { timeout: 5000 },
    async (t) => {
      const dropping = await listen((_incoming, res) => {
        res.writeHead(200, { "content-type": "text/plain", "content-length": "100" });
        res.write("partial", () => res.socket?.destroy());
      });
      const { port } = dropping.address() as AddressInfo;
      const middleware = railsProxyMiddleware({
        railsUrl: new URL(`http://127.0.0.1:${port}`),
        base: BASE,
        renderIndexHtml: async () => "",
      });
      const front = await listen((incoming, res) => middleware(incoming, res, () => {}));
      t.after(async () => {
        front.closeAllConnections();
        await close(front);
        await close(dropping);
      });
      const { port: frontPort } = front.address() as AddressInfo;

      const outcome = await new Promise<string>((resolve) => {
        const outgoing = request(
          { host: "127.0.0.1", port: frontPort, path: "/download" },
          (res) => {
            res.on("error", () => resolve("error"));
            res.on("end", () => resolve("end"));
            res.on("close", () => resolve("close"));
            res.resume();
          },
        );
        outgoing.on("error", () => resolve("error"));
        outgoing.end();
      });

      assert.notEqual(outcome, "end");
    },
  );
});
