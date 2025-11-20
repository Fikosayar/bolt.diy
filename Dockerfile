# ---------------------------------------------------
# BOLT.DIY - FINAL OPTIMIZED DOCKERFILE (Coolify)
# ---------------------------------------------------

# 1. TABAN İMAJ (Node 20 Slim - Debian tabanlı)
FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# Sistem paketlerini güncelle ve gerekli araçları kur
# python3, make, g++: Node-gyp derlemeleri için şart
# bash: Scriptlerin doğru çalışması için şart
RUN apt-get update && apt-get install -y python3 make g++ bash && rm -rf /var/lib/apt/lists/*

# pnpm ve wrangler'ı global olarak kur (Erişim sorunu olmasın)
RUN npm install -g pnpm wrangler

# 2. BAĞIMLILIKLAR (Dependencies)
FROM base AS prod-deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
# Scriptleri yoksayarak kur (Husky gibi araçlar hata vermesin)
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --prod --frozen-lockfile --ignore-scripts

# 3. DERLEME (Build)
FROM base AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
# Build için tüm paketleri (devDependencies) yüklüyoruz
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile --ignore-scripts

COPY . .

# Bellek taşmasını önlemek için RAM limiti
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Uygulamayı derle (Client ve Server)
RUN pnpm run build

# 4. ÇALIŞTIRMA (Runtime)
FROM base
WORKDIR /app

# Gerekli dosyaları önceki aşamalardan kopyala
COPY --from=prod-deps /app/node_modules /app/node_modules
COPY --from=build /app/build /app/build
COPY --from=build /app/package.json /app/package.json
# Yardımcı scriptler
COPY --from=build /app/bindings.sh /app/bindings.sh
COPY --from=build /app/worker-configuration.d.ts /app/worker-configuration.d.ts

# bindings.sh dosyasına çalıştırma izni ver ve satır sonlarını düzelt (Windows/Linux farkı için)
RUN chmod +x /app/bindings.sh && sed -i 's/\r$//' /app/bindings.sh

# Port Ayarları
ENV PORT=8788
ENV HOST=0.0.0.0
EXPOSE 8788

# --- KRİTİK DÜZELTME BÖLÜMÜ ---
# 1. Docker'a varsayılan olarak /bin/bash kullanmasını söylüyoruz (SH hatasını çözer)
SHELL ["/bin/bash", "-c"]

# 2. Başlatma Komutu:
# - bindings.sh dosyasını 'source' ile içe aktarır (Environment değişkenlerini yükler)
# - Wrangler'ı doğrudan başlatır
# - IP'yi 0.0.0.0'a ve Portu 8788'e sabitler
CMD ["source ./bindings.sh && wrangler pages dev ./build/client --ip 0.0.0.0 --port 8788 --no-open"]
