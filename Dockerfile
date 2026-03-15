# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# SARIF — Travel Intelligence Dashboard
# Runs the Vite dev server (port 5173) + Express API server (port 3001, internal).
# Only port 5173 is exposed; the API server is never reachable from the host.
# ─────────────────────────────────────────────────────────────────────────────

FROM node:24-slim

# procps provides `ps`, required by concurrently --kill-others to find child PIDs
RUN apt-get update && apt-get install -y --no-install-recommends procps \
    && rm -rf /var/lib/apt/lists/*

# Non-root user — drop privileges before running the app
RUN groupadd -r sarif && useradd -r -g sarif sarif

WORKDIR /app

# Copy manifests first so npm ci is cached until deps actually change
COPY app/package*.json ./

# Install all dependencies (dev deps needed for Vite).
# NODE_OPTIONS caps the heap to avoid OOM kills on low-memory VPS/servers.
# --no-audit --no-fund skips network round-trips that waste RAM during build.
RUN NODE_OPTIONS="--max-old-space-size=512" npm ci --no-audit --no-fund \
    && npm cache clean --force

# Copy application source and fix ownership so the sarif user can write
# temp files that Vite needs when bundling vite.config.js at startup
COPY app/ .
RUN chown -R sarif:sarif /app

USER sarif

# 5173 — Vite frontend (the only port mapped to the host)
# 3001 — Express API — intentionally NOT EXPOSE'd; Vite proxies to it internally
EXPOSE 5173

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5173',r=>process.exit(r.statusCode<500?0:1)).on('error',()=>process.exit(1))"

# concurrently is already a project dependency — use it so either process
# dying kills the other (--kill-others), preventing a zombie half-stack.
# vite --host binds to 0.0.0.0 inside the container so the mapped port is reachable.
CMD ["npx", "concurrently", "--kill-others", "--names", "api,vite", \
     "node server/index.js", \
     "vite --host 0.0.0.0"]
