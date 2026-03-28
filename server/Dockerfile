FROM node:20-alpine

# Install build dependencies for better-sqlite3
RUN apk add --no-cache python3 make g++

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY tsconfig.json ./
COPY src ./src

# Build TypeScript with increased heap size
ENV NODE_OPTIONS="--max-old-space-size=2048"
RUN npm run build

# Copy schema file to dist (needed at runtime)
RUN cp src/db/schema.sql dist/db/

# Remove dev dependencies
RUN npm prune --production

# Create data directory
RUN mkdir -p /app/data

# Set environment
ENV NODE_ENV=production
ENV PORT=3003
ENV DB_PATH=/app/data/obsession-api.db

EXPOSE 3003

CMD ["node", "dist/index.js"]
