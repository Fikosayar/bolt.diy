# Node 20 (En stabil)
FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable
# Python ve gerekli araçlar
RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

# --- AŞAMA 1: BAĞIMLILIKLAR ---
FROM base AS prod-deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
# DÜZELTME BURADA: --ignore-scripts eklendi (Husky hatasını çözer)
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --prod --frozen-lockfile --ignore-scripts

# --- AŞAMA 2: DERLEME (BUILD) ---
FROM base AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
# Build için tüm paketler lazım (ignore-scripts burada da güvenli olabilir ama build scriptleri çalışmalı)
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile --ignore-scripts
COPY . .
# Bellek ayarı
ENV NODE_OPTIONS="--max-old-space-size=4096"
# Uygulamayı derle
RUN pnpm run build

# --- AŞAMA 3: ÇALIŞTIRMA ---
FROM base
WORKDIR /app
COPY --from=prod-deps /app/node_modules /app/node_modules
COPY --from=build /app/build /app/build
COPY --from=build /app/package.json /app/package.json

# Port Ayarı
ENV PORT=5173
ENV HOST=0.0.0.0
EXPOSE 5173

# Başlat
CMD [ "pnpm", "start" ]
