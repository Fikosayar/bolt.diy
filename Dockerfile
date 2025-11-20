# 1. Taban İmaj
FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# DÜZELTME BURADA: Wrangler'ı global olarak kuruyoruz ki sistem tanısın
RUN npm install -g pnpm wrangler

RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

# 2. Bağımlılıklar
FROM base AS prod-deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
# --prod kaldırdık, her şeyi yüklesin ki eksik çıkmasın
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile --ignore-scripts

# 3. Derleme (Build)
FROM base AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile --ignore-scripts
COPY . .
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN pnpm run build

# 4. Çalıştırma
FROM base
WORKDIR /app

COPY --from=prod-deps /app/node_modules /app/node_modules
COPY --from=build /app/build /app/build
COPY --from=build /app/package.json /app/package.json
COPY --from=build /app/bindings.sh /app/bindings.sh
COPY --from=build /app/worker-configuration.d.ts /app/worker-configuration.d.ts

# Dosya izinlerini ve Wrangler'ı garantiye alıyoruz
RUN chmod +x /app/bindings.sh

ENV PORT=5173
ENV HOST=0.0.0.0
EXPOSE 5173

CMD [ "pnpm", "start" ]
