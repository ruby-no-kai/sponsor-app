import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { railsProxy } from "./vite/rails-proxy.ts";

// The dev server is the SPA's origin: it renders SPA paths itself and proxies every other request
// to Rails, so both share one host. Vite's own files stay under base, clear of Rails' paths.
export default defineConfig({
  base: "/_ui/",
  server: {
    // Vite's CORS middleware runs before the proxy and would alter Rails' responses.
    cors: false,
  },
  plugins: [
    react(),
    tailwindcss(),
    railsProxy(process.env.SPONSOR_APP_RAILS_URL ?? "http://127.0.0.1:3000"),
  ],
  build: {
    sourcemap: true,
  },
});
