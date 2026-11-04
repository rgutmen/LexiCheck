import { defineConfig } from "vite-plus";
import react from "@vitejs/plugin-react";

// Single config for dev server, build, lint (Oxlint) and format (Oxfmt).
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // In dev, proxy /api to the local API so the browser talks to a single origin,
    // exactly like production where CloudFront routes /api/* to the load balancer.
    proxy: {
      "/api": {
        target: process.env.API_PROXY_TARGET ?? "http://localhost:8080",
        rewrite: (path) => path.replace(/^\/api/, ""),
      },
    },
  },
  lint: {
    ignorePatterns: ["node_modules/**", "dist/**"],
    options: { typeAware: true, typeCheck: true },
  },
  fmt: {
    printWidth: 100,
    ignorePatterns: ["node_modules/**", "dist/**"],
  },
});
