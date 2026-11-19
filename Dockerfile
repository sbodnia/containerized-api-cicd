FROM node:22-alpine@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a AS deps
WORKDIR /app
# hadolint ignore=DL3022
COPY --from=upstream src/package.json src/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev
RUN find node_modules -name "*.md" -delete && find node_modules -name "*.map" -delete

FROM node:22-alpine@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a AS runtime
# hadolint ignore=DL3018
RUN apk add --no-cache tini
ARG UPSTREAM_SHA
ARG SOURCE_URL=https://github.com/sbodnia/containerized-api-cicd
LABEL org.opencontainers.image.source="${SOURCE_URL}" \
      org.opencontainers.image.revision="${UPSTREAM_SHA}" \
      org.opencontainers.image.title="demoapp"
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps --chown=1000:1000 /app/node_modules ./node_modules
# hadolint ignore=DL3022
COPY --from=upstream --chown=1000:1000 src/ ./
USER 1000:1000
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD ["node", "-e", "fetch('http://localhost:3000/').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "--expose_gc", "server.mjs"]