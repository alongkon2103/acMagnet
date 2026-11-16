FROM node:22-bookworm-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY bridge ./bridge
COPY data ./data
RUN mkdir -p /app/runtime && chown node:node /app/runtime
ENV HOST=0.0.0.0 PORT=8787
EXPOSE 8787
USER node
CMD ["node", "bridge/server.mjs"]
