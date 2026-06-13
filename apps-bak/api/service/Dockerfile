FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --only=production

COPY src ./src

EXPOSE 3000
CMD ["node", "src/index.js"]

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:3000/ready || exit 1

