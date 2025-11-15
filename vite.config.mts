import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";
import FullReload from "vite-plugin-full-reload";
import checker from "vite-plugin-checker";

export default defineConfig({
  plugins: [
    checker({ typescript: true }),
    FullReload(["config/routes.rb", "app/views/**/*"]),
    RubyPlugin(),
  ],
  resolve: {
    extensions: [".js", ".ts", ".tsx", ".jsx", ".css", ".scss", ".sass"],
  },
  build: {
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: (id) => {
          // Split vendor chunks for better caching
          if (id.includes("node_modules")) {
            // Group common vendor libraries together
            if (
              id.includes("react") ||
              id.includes("react-dom") ||
              id.includes("@sentry")
            ) {
              return "vendor";
            }
            if (
              id.includes("bootstrap") ||
              id.includes("jquery") ||
              id.includes("popper")
            ) {
              return "vendor";
            }
          }
        },
      },
    },
  },
  define: {
    // Provide jQuery globally for Bootstrap 4 compatibility
    global: "globalThis",
  },
});
