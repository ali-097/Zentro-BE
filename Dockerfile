# Production image. For local development see Dockerfile.dev.
#
# Multi-stage so the runtime image carries no build toolchain, no dev dependencies and no
# TypeScript sources — smaller to ship and a smaller attack surface.

# ─── Stage 1: dependencies ────────────────────────────────────────────────────
FROM node:22-alpine AS deps
WORKDIR /app

# Copy manifests only. This layer is cached and rebuilt just when dependencies change,
# not on every source edit.
COPY package.json package-lock.json ./
RUN npm ci

# ─── Stage 2: build ───────────────────────────────────────────────────────────
FROM node:22-alpine AS build
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Strip dev dependencies from the tree we're about to copy forward.
RUN npm prune --omit=dev

# ─── Stage 3: runtime ─────────────────────────────────────────────────────────
FROM node:22-alpine AS runtime
WORKDIR /app

ENV NODE_ENV=production

# dumb-init reaps zombies and forwards signals, so SIGTERM actually reaches Node and the
# container shuts down gracefully instead of being killed after the timeout.
RUN apk add --no-cache dumb-init

# Run unprivileged. node:alpine ships a `node` user for exactly this.
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --from=build --chown=node:node /app/package.json ./package.json

USER node

EXPOSE 3000

# The platform's health check should target this endpoint.
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main"]
