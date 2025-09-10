# ===========================================
# Legal RAG Mexico - Production Dockerfile
# Multi-stage build for optimized Flutter web
# ===========================================

# Stage 1: Build the Flutter web application
FROM ghcr.io/cirruslabs/flutter:3.19.0 AS builder

# Set working directory
WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get Flutter dependencies
RUN flutter pub get

# Copy the entire project
COPY . .

# Create .env file from build args (secure way to pass secrets during build)
ARG DEEPSEEK_API_KEY
ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY
ARG MILVUS_HOST
ARG MILVUS_PORT
ARG OPENROUTER_API_KEY
ARG APP_ENV=production

# Create .env file with build arguments
RUN echo "DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}" > .env && \
    echo "SUPABASE_URL=${SUPABASE_URL}" >> .env && \
    echo "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" >> .env && \
    echo "MILVUS_HOST=${MILVUS_HOST}" >> .env && \
    echo "MILVUS_PORT=${MILVUS_PORT}" >> .env && \
    echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY}" >> .env && \
    echo "APP_ENV=${APP_ENV}" >> .env && \
    echo "API_TIMEOUT=30000" >> .env && \
    echo "MAX_RETRIES=3" >> .env && \
    echo "ENABLE_LOGGING=false" >> .env && \
    echo "ENABLE_CHAT_HISTORY=true" >> .env && \
    echo "ENABLE_DOCUMENT_UPLOAD=true" >> .env && \
    echo "ENABLE_PREMIUM_FEATURES=true" >> .env

# Build the Flutter web application
RUN flutter build web --release --web-renderer canvaskit --dart-define=FLUTTER_WEB_USE_SKIA=true

# Stage 2: Serve the application with Nginx
FROM nginx:alpine AS production

# Install necessary packages
RUN apk add --no-cache \
    curl \
    ca-certificates \
    tzdata

# Set timezone
ENV TZ=America/Mexico_City
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

# Create non-root user for security
RUN addgroup -g 1001 -S flutter && \
    adduser -u 1001 -S flutter -G flutter

# Copy the built Flutter web app from builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Create necessary directories and set permissions
RUN mkdir -p /var/cache/nginx /var/log/nginx /var/run && \
    chown -R flutter:flutter /var/cache/nginx /var/log/nginx /var/run /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Expose port 80
EXPOSE 80

# Switch to non-root user
USER flutter

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]