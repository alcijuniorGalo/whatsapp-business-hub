FROM node:20-alpine

WORKDIR /app

# Dependências primeiro (cache de layer)
COPY package.json ./
RUN npm install --omit=dev

COPY webhook_server.js ./

# Diretório do log de eventos (monte um volume em produção)
RUN mkdir -p /app/data
VOLUME /app/data

ENV PORT=3000
EXPOSE 3000

# Healthcheck simples
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/events/since || exit 1

CMD ["node", "webhook_server.js"]
