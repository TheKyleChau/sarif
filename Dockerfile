# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# SARIF — Travel Intelligence Dashboard
# Runs the Vite dev server (port 5173) + Express API server (port 3001, internal).
# Only port 5173 is exposed; the API server is never reachable from the host.
# ─────────────────────────────────────────────────────────────────────────────

FROM node:24-slim

# Non-root user — drop privileges before running the app
RUN groupadd -r sarif && useradd -r -g sarif -m sarif

WORKDIR /app

# Copy manifests first so npm ci is cached until deps actually change
COPY app/package*.json ./

# Install all dependencies (dev deps needed for Vite).
# --no-audit --no-fund skips network round-trips during build.
RUN npm ci --no-audit --no-fund && npm cache clean --force

# Copy application source and hand ownership to sarif so Vite can write
# its config timestamp file (.vite.config.js.timestamp-*.mjs) at startup
COPY app/ .
RUN chown -R sarif:sarif /app

USER sarif

# 5173 — Vite frontend (the only port mapped to the host)
# 3001 — Express API — intentionally NOT EXPOSE'd; Vite proxies to it internally
EXPOSE 5173

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5173',r=>process.exit(r.statusCode<500?0:1)).on('error',()=>process.exit(1))"

# Plain shell — no concurrently, no `ps` required.
# If vite exits, the script exits and Docker restarts the container.
CMD ["sh", "-c", "node server/index.js & npx vite --host 0.0.0.0"]
