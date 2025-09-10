#!/bin/bash

# =====================================================
# ONE-COMMAND DEPLOYMENT TO HETZNER
# LegalTracking RAG System
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
SERVER_NAME="LegalTracking-Rag-System"
SSH_KEY="./hetzner_key"
APP_DIR="/opt/legal-rag-mexico"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🚀 LegalTracking RAG - One-Click Deployment${NC}"
echo -e "${BLUE}================================================${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check SSH key
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key not found at $SSH_KEY${NC}"
    exit 1
fi

chmod 600 "$SSH_KEY"
echo -e "${GREEN}✓ SSH key found${NC}"

# Check .env file
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Warning: .env file not found${NC}"
    echo -e "${YELLOW}Creating .env from template...${NC}"
    
    cat > .env << 'EOF'
# DeepSeek API Configuration
DEEPSEEK_API_KEY=your_deepseek_api_key_here

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here

# Milvus Vector Database
MILVUS_HOST=localhost
MILVUS_PORT=19530

# OpenRouter API (Optional)
OPENROUTER_API_KEY=your_openrouter_api_key_here

# Application Settings
APP_ENV=production
APP_PORT=80
EOF
    
    echo -e "${RED}Please edit .env with your actual API keys!${NC}"
    echo -e "${YELLOW}Then run this script again.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Environment file found${NC}"

# Test SSH connection
echo -e "${YELLOW}Testing server connection...${NC}"
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$SSH_KEY" root@$SERVER_IP "echo 'Connection successful'" &>/dev/null; then
    echo -e "${GREEN}✓ Server connection successful${NC}"
else
    echo -e "${RED}Cannot connect to server. Setting up server first...${NC}"
    
    # Run server setup
    echo -e "${YELLOW}Running initial server setup...${NC}"
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" root@$SERVER_IP 'bash -s' < setup-legaltracking-server.sh
fi

# Build Flutter web app
echo -e "${YELLOW}Building Flutter web application...${NC}"
if command -v flutter &> /dev/null; then
    flutter clean
    flutter pub get
    flutter build web --release --web-renderer html
    echo -e "${GREEN}✓ Flutter build completed${NC}"
else
    echo -e "${YELLOW}Flutter not found locally, will build on server${NC}"
fi

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
tar czf deploy.tar.gz \
    Dockerfile \
    docker-compose.yml \
    nginx.conf \
    default.conf \
    .dockerignore \
    .env \
    lib/ \
    web/ \
    build/ \
    pubspec.yaml \
    pubspec.lock \
    --exclude='*.log' \
    --exclude='node_modules' \
    --exclude='.dart_tool' \
    2>/dev/null || true

echo -e "${GREEN}✓ Deployment package created${NC}"

# Upload to server
echo -e "${YELLOW}Uploading to server...${NC}"
ssh -i "$SSH_KEY" root@$SERVER_IP "mkdir -p $APP_DIR"
scp -i "$SSH_KEY" deploy.tar.gz root@$SERVER_IP:$APP_DIR/
echo -e "${GREEN}✓ Files uploaded${NC}"

# Deploy on server
echo -e "${YELLOW}Deploying application...${NC}"
ssh -i "$SSH_KEY" root@$SERVER_IP << 'REMOTE_DEPLOY'
set -e

APP_DIR="/opt/legal-rag-mexico"
cd $APP_DIR

# Extract deployment package
echo "Extracting files..."
tar xzf deploy.tar.gz

# Ensure Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
fi

# Ensure Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo "Installing Docker Compose..."
    apt-get update && apt-get install -y docker-compose-plugin
fi

# Stop existing containers
docker compose down 2>/dev/null || true

# Build and start services
echo "Building Docker images..."
docker compose build --no-cache

echo "Starting services..."
docker compose up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 15

# Health check
echo "Performing health check..."
for i in {1..30}; do
    if curl -f http://localhost/health &>/dev/null; then
        echo "✓ Application is healthy"
        break
    fi
    echo "Waiting for application to be ready... ($i/30)"
    sleep 2
done

# Show status
docker compose ps

# Setup nginx if not configured
if [ ! -f /etc/nginx/sites-available/legal-rag ]; then
    echo "Configuring Nginx..."
    cat > /etc/nginx/sites-available/legal-rag << 'NGINX_CONFIG'
server {
    listen 80;
    server_name _;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
NGINX_CONFIG
    
    ln -sf /etc/nginx/sites-available/legal-rag /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
fi

echo "================================================"
echo "✅ DEPLOYMENT COMPLETE!"
echo "================================================"
REMOTE_DEPLOY

# Cleanup local files
rm deploy.tar.gz

# Get application URL
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ DEPLOYMENT SUCCESSFUL!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Application URLs:${NC}"
echo -e "  Direct IP: ${GREEN}http://$SERVER_IP${NC}"
echo ""
echo -e "${BLUE}Server Access:${NC}"
echo -e "  SSH: ssh -i $SSH_KEY root@$SERVER_IP"
echo -e "  Logs: ssh -i $SSH_KEY root@$SERVER_IP 'docker compose -f $APP_DIR/docker-compose.yml logs -f'"
echo ""
echo -e "${BLUE}Management Commands:${NC}"
echo -e "  Status: ./monitor-legalrag.sh"
echo -e "  Connect: ./connect-legalrag.sh"
echo -e "  Deploy: ./deploy-to-hetzner.sh"
echo ""
echo -e "${GREEN}================================================${NC}"

# Optional: Open browser
if command -v xdg-open &> /dev/null; then
    echo -e "${YELLOW}Opening application in browser...${NC}"
    xdg-open "http://$SERVER_IP" 2>/dev/null || true
elif command -v open &> /dev/null; then
    open "http://$SERVER_IP" 2>/dev/null || true
fi