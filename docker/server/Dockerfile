# Parasprite Radio web server (node). Build context is the repo root.

# --- build the frontend (gulp: webpack, stylus, pug) ---
FROM node:24-trixie-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
# gulp reads conf/radio.toml for site settings; fall back to the defaults
RUN [ -f conf/radio.toml ] || cp conf/radio.default.toml conf/radio.toml
RUN NODE_ENV=production npx gulp script style document

# --- runtime ---
FROM node:24-trixie-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends graphicsmagick ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

COPY .babelrc knexfile.js ./
COPY bin ./bin
COPY server ./server
COPY scripts ./scripts
COPY migrations ./migrations
COPY static ./static
COPY --from=build /app/build ./build

# conf/radio.toml is mounted at runtime (see docker-compose.yml)
# @babel/register keeps its cache here
RUN mkdir -p conf node_modules/.cache && chown -R node:node node_modules/.cache
USER node

EXPOSE 8002
CMD ["node", "bin/startserver"]
