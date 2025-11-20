# 1. Taban İmaj
FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable
RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

# 2. Derleme ve Kurulum (Tek Aşamada Hepsini Hazırlayalım)
FROM base AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
# Wrangler ve diğer araçların çalışması için tüm bağımlılıkları yüklüyoruz
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile --ignore-scripts

COPY . .
# Bellek ayarı
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN pnpm run build

# 3. Çalıştırma (Final Sahnesi)
FROM base
WORKDIR /app

# Build aşamasından her şeyi alıyoruz (Node_modules dahil)
COPY --from=build /app/node_modules /app/node_modules
COPY --from=build /app/build /app/build
COPY --from=build /app/package.json /app/package.json

# İŞTE EKSİK OLAN PARÇA BUYDU:
COPY --from=build /app/bindings.sh /app/bindings.sh

# Dosyaya çalıştırma izni veriyoruz
RUN chmod +x /app/bindings.sh

ENV PORT=5173
ENV HOST=0.0.0.0
EXPOSE 5173

CMD [ "pnpm", "start" ]
