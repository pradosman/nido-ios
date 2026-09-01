ARG NODE_IMAGE=node:24.19.0-bookworm-slim@sha256:a9f5f7c91a432850b2a8a7797adf5eadb6c733ceed61167806cee7ea7fbc29df

FROM ${NODE_IMAGE} AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM dependencies AS build
COPY . .
RUN npm run build

FROM ${NODE_IMAGE} AS runtime
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000
WORKDIR /app

RUN groupadd --system --gid 10001 nido \
    && useradd --system --uid 10001 --gid nido --home-dir /nonexistent --shell /usr/sbin/nologin nido

COPY --from=build --chown=root:root /app/dist/standalone ./dist/standalone
COPY --from=build --chown=root:root /app/dist/migrate.mjs ./dist/migrate.mjs
COPY --from=build --chown=root:root /app/drizzle-pg ./drizzle-pg
COPY --from=build --chown=root:root /app/deploy/entrypoint.sh ./deploy/entrypoint.sh
RUN chmod 0555 ./deploy/entrypoint.sh \
    && find /app -type d -exec chmod 0555 {} + \
    && find /app -type f ! -path '/app/deploy/entrypoint.sh' -exec chmod 0444 {} +

USER nido
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:3000/api/nido/status').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"]

ENTRYPOINT ["/app/deploy/entrypoint.sh"]
CMD ["serve"]
