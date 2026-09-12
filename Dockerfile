# Multi-stage build para otimização de segurança e tamanho de imagem
# Stage 1: Build
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --legacy-peer-deps

COPY . .
RUN npm run build

# Stage 2: Production Runtime
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --only=production --legacy-peer-deps && npm cache clean --force

# Copia os arquivos compilados do TypeScript
COPY --from=builder /app/dist ./dist

# Prática de segurança (DevSecOps): executando com usuário não-root
USER node

EXPOSE 3000

CMD ["node", "dist/server.js"]