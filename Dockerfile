FROM node:24-bookworm-slim AS build

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:24-bookworm-slim AS runtime

ENV NODE_ENV=production \
    NIDO_DATA_DIR=/data \
    WRANGLER_SEND_METRICS=false \
    CI=true
WORKDIR /app

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/drizzle ./drizzle
COPY --from=build /app/deploy ./deploy
COPY --from=build /app/wrangler.vps.jsonc ./wrangler.vps.jsonc

RUN chmod +x ./deploy/entrypoint.sh \
    && mkdir -p /data \
    && chown -R node:node /app /data

USER node

EXPOSE 3000
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:3000/api/nido/status').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"]

ENTRYPOINT ["./deploy/entrypoint.sh"]
