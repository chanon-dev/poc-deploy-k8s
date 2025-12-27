# Multi-stage Dockerfile for Next.js Webapp
# Production-ready with security hardening

# Stage 1: Dependencies
FROM node:20.18.1-alpine3.20 AS deps

# Metadata labels
LABEL org.opencontainers.image.title="Webapp Dependencies" \
      org.opencontainers.image.description="Next.js Webapp Dependencies" \
      org.opencontainers.image.vendor="Platform Team" \
      maintainer="platform-team@example.com"

WORKDIR /app

# Install dependencies with clean cache
COPY package.json package-lock.json* ./
RUN npm ci --only=production --ignore-scripts && \
    npm cache clean --force

# Stage 2: Builder
FROM node:20.18.1-alpine3.20 AS builder

LABEL org.opencontainers.image.title="Webapp Builder" \
      org.opencontainers.image.description="Next.js Build Stage"

WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Set environment variables for build
ENV NEXT_TELEMETRY_DISABLED=1 \
    NODE_ENV=production

# Build the application
RUN npm run build

# Stage 3: Runner
FROM node:20.18.1-alpine3.20 AS runner

# Metadata
LABEL org.opencontainers.image.title="Webapp Runtime" \
      org.opencontainers.image.description="Next.js Webapp Runtime" \
      org.opencontainers.image.version="1.0.0"

WORKDIR /app

# Environment variables
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME="0.0.0.0"

# Security: Create non-root user with specific UID matching Kubernetes securityContext
RUN addgroup -g 1000 nodejs && \
    adduser -u 1000 -G nodejs -s /bin/sh -D nextjs && \
    chown -R nextjs:nodejs /app

# Create .next directory with proper permissions
RUN mkdir -p .next && \
    chown -R nextjs:nodejs .next

# Copy built application with proper ownership
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Security: Switch to non-root user
USER nextjs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

# Start the application
CMD ["node", "server.js"]
