# Authentication Service Dockerfile (B:container003)
FROM node:18-alpine AS base

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    curl \
    ca-certificates \
    openssl \
    dumb-init \
    && addgroup -g 1001 -S nodejs \
    && adduser -S auth -u 1001 -G nodejs

# Copy package files
COPY package*.json ./
COPY yarn.lock* ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application source
COPY --chown=auth:nodejs . .

# Create necessary directories
RUN mkdir -p /app/keys /app/logs && \
    chown -R auth:nodejs /app/keys /app/logs && \
    chmod 700 /app/keys && \
    chmod 755 /app/logs

# Security: Run as non-root user
USER auth

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Environment variables
ENV NODE_ENV=production \
    PORT=4000 \
    KEY_STORAGE_PATH=/app/keys

# Expose port
EXPOSE 4000

# Use dumb-init for proper signal handling
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "auth-server.js"]

# Labels
LABEL maintainer="MCP Auth Team" \
      version="1.0" \
      description="Bitcoin NFT Authentication Service Container"
