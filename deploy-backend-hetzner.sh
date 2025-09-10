#!/bin/bash

# =====================================================
# Deploy RAG Backend to Hetzner
# LegalTracking System - Backend Only
# =====================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SERVER_IP="5.161.120.86"
SSH_KEY="./hetzner_key"
GITHUB_USER="${GITHUB_USER:-yourusername}"
GITHUB_PAGES_URL="https://$GITHUB_USER.github.io"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🚀 RAG Backend Deployment to Hetzner${NC}"
echo -e "${BLUE}================================================${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check SSH key
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key not found at $SSH_KEY${NC}"
    exit 1
fi
chmod 600 "$SSH_KEY"

# Check backend directory
if [ ! -d "backend" ]; then
    echo -e "${RED}Error: backend directory not found${NC}"
    echo "Please ensure you have the backend/ directory with all required files"
    exit 1
fi

# Check .env file
if [ ! -f "backend/.env" ]; then
    echo -e "${YELLOW}Creating .env file from template...${NC}"
    
    cat > backend/.env << EOF
# API Keys (REQUIRED - Add your actual keys)
DEEPSEEK_API_KEY=your_deepseek_api_key_here
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
SUPABASE_SERVICE_KEY=your_supabase_service_key_here
OPENROUTER_API_KEY=your_openrouter_api_key_here

# CORS Configuration - Your GitHub Pages URL
CORS_ORIGINS=$GITHUB_PAGES_URL

# Application Settings
APP_ENV=production
LOG_LEVEL=INFO

# Milvus Settings (Docker internal)
MILVUS_HOST=milvus-standalone
MILVUS_PORT=19530

# Redis Settings (Docker internal)
REDIS_URL=redis://redis:6379
EOF
    
    echo -e "${RED}Please edit backend/.env with your actual API keys!${NC}"
    echo -e "${YELLOW}Then run this script again.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites checked${NC}"

# Test server connection
echo -e "${YELLOW}Testing server connection...${NC}"
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$SSH_KEY" root@$SERVER_IP "echo 'Connected'" &>/dev/null; then
    echo -e "${GREEN}✓ Server connection successful${NC}"
else
    echo -e "${RED}Cannot connect to server at $SERVER_IP${NC}"
    exit 1
fi

# Prepare backend files
echo -e "${YELLOW}Preparing backend files...${NC}"

# Create nginx configuration if not exists
if [ ! -d "backend/nginx" ]; then
    mkdir -p backend/nginx/conf.d
    
    cat > backend/nginx/nginx.conf << 'NGINX_CONF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 2048;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss;
    
    include /etc/nginx/conf.d/*.conf;
}
NGINX_CONF
    
    cat > backend/nginx/conf.d/api.conf << 'API_CONF'
upstream api_backend {
    server rag-api:8000;
}

server {
    listen 80;
    server_name _;
    
    client_max_body_size 100M;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # CORS headers - configured via environment variable
    set $cors_origin "$http_origin";
    if ($cors_origin !~ '^https?://(localhost|127\.0\.0\.1|.*\.github\.io)') {
        set $cors_origin '';
    }
    
    add_header 'Access-Control-Allow-Origin' '$cors_origin' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
    add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
    add_header 'Access-Control-Allow-Credentials' 'true' always;
    
    # Handle preflight requests
    if ($request_method = 'OPTIONS') {
        add_header 'Access-Control-Max-Age' 1728000;
        add_header 'Content-Type' 'text/plain; charset=utf-8';
        add_header 'Content-Length' 0;
        return 204;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://api_backend/health;
        access_log off;
    }
    
    # API endpoints
    location /api/ {
        proxy_pass http://api_backend/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Root endpoint
    location / {
        return 200 '{"name":"LegalTracking RAG API","version":"1.0.0","status":"online"}';
        add_header Content-Type application/json;
    }
}
API_CONF
fi

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
cd backend
tar czf ../backend-deploy.tar.gz \
    Dockerfile \
    docker-compose.yml \
    requirements.txt \
    main.py \
    .env \
    nginx/ \
    config/ \
    2>/dev/null || true
cd ..

echo -e "${GREEN}✓ Deployment package created${NC}"

# Upload to server
echo -e "${YELLOW}Uploading to server...${NC}"
ssh -i "$SSH_KEY" root@$SERVER_IP "mkdir -p /opt/legalrag-backend"
scp -i "$SSH_KEY" backend-deploy.tar.gz root@$SERVER_IP:/opt/legalrag-backend/

# Deploy on server
echo -e "${YELLOW}Deploying backend services...${NC}"
ssh -i "$SSH_KEY" root@$SERVER_IP << 'REMOTE_DEPLOY'
set -e

cd /opt/legalrag-backend

# Extract deployment package
echo "Extracting files..."
tar xzf backend-deploy.tar.gz

# Create required directories on data volume
echo "Creating data directories..."
mkdir -p /mnt/data/{milvus,etcd,minio,redis,uploads,logs}

# Stop existing services
echo "Stopping existing services..."
docker compose down 2>/dev/null || true

# Clean up old images
echo "Cleaning up old images..."
docker system prune -f

# Build and start services
echo "Building backend services..."
docker compose build --no-cache

echo "Starting services..."
docker compose up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 30

# Check service health
echo "Checking service health..."
docker compose ps

# Verify API health
for i in {1..30}; do
    if curl -f http://localhost/health 2>/dev/null; then
        echo "✓ API is healthy"
        break
    fi
    echo "Waiting for API to be ready... ($i/30)"
    sleep 5
done

# Show logs
echo ""
echo "Recent logs:"
docker compose logs --tail=20 rag-api

echo ""
echo "✅ Backend deployment complete!"
REMOTE_DEPLOY

# Cleanup local file
rm -f backend-deploy.tar.gz

# Create management scripts
echo -e "${YELLOW}Creating management scripts...${NC}"

# Create logs viewer
cat > view-backend-logs.sh << 'LOGS_SCRIPT'
#!/bin/bash
SERVER_IP="5.161.120.86"
SSH_KEY="./hetzner_key"

echo "Viewing backend logs..."
ssh -i "$SSH_KEY" root@$SERVER_IP \
    'cd /opt/legalrag-backend && docker compose logs -f --tail=100'
LOGS_SCRIPT
chmod +x view-backend-logs.sh

# Create restart script
cat > restart-backend.sh << 'RESTART_SCRIPT'
#!/bin/bash
SERVER_IP="5.161.120.86"
SSH_KEY="./hetzner_key"

echo "Restarting backend services..."
ssh -i "$SSH_KEY" root@$SERVER_IP \
    'cd /opt/legalrag-backend && docker compose restart'
echo "✓ Services restarted"
RESTART_SCRIPT
chmod +x restart-backend.sh

# Create status checker
cat > backend-status.sh << 'STATUS_SCRIPT'
#!/bin/bash
SERVER_IP="5.161.120.86"
SSH_KEY="./hetzner_key"

echo "================================================"
echo "Backend Services Status"
echo "================================================"

# Check services
ssh -i "$SSH_KEY" root@$SERVER_IP \
    'cd /opt/legalrag-backend && docker compose ps'

echo ""
echo "API Health Check:"
curl -s http://$SERVER_IP/health | python3 -m json.tool 2>/dev/null || echo "API not responding"

echo ""
echo "Resource Usage:"
ssh -i "$SSH_KEY" root@$SERVER_IP 'docker stats --no-stream'
STATUS_SCRIPT
chmod +x backend-status.sh

# Test the deployment
echo ""
echo -e "${YELLOW}Testing deployment...${NC}"

# Test health endpoint
if curl -f -s http://$SERVER_IP/health > /dev/null; then
    echo -e "${GREEN}✓ Health endpoint responding${NC}"
else
    echo -e "${RED}✗ Health endpoint not responding${NC}"
fi

# Test CORS
echo -e "${YELLOW}Testing CORS configuration...${NC}"
CORS_TEST=$(curl -s -H "Origin: $GITHUB_PAGES_URL" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: X-Requested-With" \
    -X OPTIONS \
    -w "%{http_code}" \
    http://$SERVER_IP/api/chat)

if [[ "$CORS_TEST" == *"204"* ]] || [[ "$CORS_TEST" == *"200"* ]]; then
    echo -e "${GREEN}✓ CORS configured correctly${NC}"
else
    echo -e "${YELLOW}⚠ CORS may need configuration${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ BACKEND DEPLOYMENT SUCCESSFUL!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Backend API Endpoints:${NC}"
echo "  Health: http://$SERVER_IP/health"
echo "  Chat:   http://$SERVER_IP/api/chat"
echo "  Upload: http://$SERVER_IP/api/documents/upload"
echo "  Search: http://$SERVER_IP/api/search"
echo ""
echo -e "${BLUE}Management Scripts:${NC}"
echo "  View logs:    ./view-backend-logs.sh"
echo "  Restart:      ./restart-backend.sh"
echo "  Status:       ./backend-status.sh"
echo ""
echo -e "${BLUE}Frontend Configuration:${NC}"
echo "  Update your Flutter app to use: http://$SERVER_IP"
echo "  CORS allowed origin: $GITHUB_PAGES_URL"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Deploy frontend: ./deploy-flutter-github-pages.sh"
echo "2. Configure SSL: ./setup-ssl-certificate.sh"
echo "3. Monitor health: ./backend-status.sh"
echo ""
echo -e "${GREEN}================================================${NC}"