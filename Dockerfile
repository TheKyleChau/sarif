# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# SARIF — Travel Intelligence Dashboard
# Runs the Vite dev server (port 5173) + Express API server (port 3001, internal).
# Only port 5173 is exposed; the API server is never reachable from the host.
# ─────────────────────────────────────────────────────────────────────────────

FROM node:22-alpine

# Non-root user — drop privileges before running the app
RUN addgroup -S sarif && adduser -S sarif -G sarif

WORKDIR /app

# Copy manifests first so npm ci is cached until deps actually change
COPY app/package*.json ./

# Install all dependencies (dev deps needed for Vite)
RUN npm ci && npm cache clean --force

# Copy application source
COPY app/ .

USER sarif

# 5173 — Vite frontend (the only port mapped to the host)
# 3001 — Express API — intentionally NOT EXPOSE'd; Vite proxies to it internally
EXPOSE 5173

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://localhost:5173/ || exit 1

# concurrently is already a project dependency — use it so either process
# dying kills the other (--kill-others), preventing a zombie half-stack.
# vite --host binds to 0.0.0.0 inside the container so the mapped port is reachable.
CMD ["npx", "concurrently", "--kill-others", "--names", "api,vite", \
     "node server/index.js", \
     "vite --host 0.0.0.0"]
