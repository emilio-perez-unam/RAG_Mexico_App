#!/bin/bash

# =====================================================
# Hetzner CLI Setup and Auto-Login Script
# For LegalTracking-Rag-System
# Server IP: 5.161.120.86
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
SERVER_IPV6="2a01:4ff:f0:69ab::/64"
SERVER_NAME="LegalTracking-Rag-System"
SSH_KEY_PATH="./hetzner_key.pub"
SSH_PRIVATE_KEY_PATH="./hetzner_key"  # Assuming private key is named hetzner_key

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Hetzner CLI Setup & Auto-Configuration${NC}"
echo -e "${BLUE}================================================${NC}"

# Step 1: Check if SSH keys exist
echo -e "${YELLOW}Step 1: Checking SSH keys...${NC}"

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}Error: SSH public key not found at $SSH_KEY_PATH${NC}"
    echo -e "${YELLOW}Please ensure hetzner_key.pub is in the current directory${NC}"
    exit 1
fi

if [ ! -f "$SSH_PRIVATE_KEY_PATH" ]; then
    echo -e "${YELLOW}Warning: SSH private key not found at $SSH_PRIVATE_KEY_PATH${NC}"
    echo -e "${YELLOW}Looking for private key without extension...${NC}"
    
    # Check for key without extension
    if [ -f "./hetzner_key" ]; then
        SSH_PRIVATE_KEY_PATH="./hetzner_key"
        echo -e "${GREEN}Found private key at ./hetzner_key${NC}"
    else
        echo -e "${RED}Private key not found. Please ensure it's in the current directory${NC}"
        exit 1
    fi
fi

# Set correct permissions for SSH key
chmod 600 "$SSH_PRIVATE_KEY_PATH"
chmod 644 "$SSH_KEY_PATH"

echo -e "${GREEN}✓ SSH keys found and permissions set${NC}"

# Step 2: Install Hetzner CLI if not installed
echo -e "${YELLOW}Step 2: Installing Hetzner CLI...${NC}"

if ! command -v hcloud &> /dev/null; then
    echo "Installing Hetzner CLI..."
    
    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -o hcloud.tar.gz -L https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz
        tar xzf hcloud.tar.gz
        sudo mv hcloud /usr/local/bin/
        rm hcloud.tar.gz
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install hcloud
        else
            curl -o hcloud.tar.gz -L https://github.com/hetznercloud/cli/releases/latest/download/hcloud-darwin-amd64.tar.gz
            tar xzf hcloud.tar.gz
            sudo mv hcloud /usr/local/bin/
            rm hcloud.tar.gz
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        # Windows
        echo -e "${YELLOW}Please download hcloud from: https://github.com/hetznercloud/cli/releases${NC}"
        echo -e "${YELLOW}And add it to your PATH${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Hetzner CLI installed${NC}"
else
    echo -e "${GREEN}✓ Hetzner CLI already installed${NC}"
fi

# Step 3: Configure Hetzner CLI
echo -e "${YELLOW}Step 3: Configuring Hetzner CLI...${NC}"

# Check if we have an API token
if [ -z "$HCLOUD_TOKEN" ]; then
    echo -e "${YELLOW}No HCLOUD_TOKEN found in environment${NC}"
    echo -e "${BLUE}Please enter your Hetzner Cloud API token:${NC}"
    echo -e "${YELLOW}(Get it from: https://console.hetzner.cloud/projects -> Security -> API Tokens)${NC}"
    read -s HCLOUD_TOKEN
    echo
    
    # Save to environment file for future use
    echo "export HCLOUD_TOKEN='$HCLOUD_TOKEN'" >> ~/.bashrc
    echo "export HCLOUD_TOKEN='$HCLOUD_TOKEN'" >> ~/.zshrc 2>/dev/null || true
fi

# Create/update Hetzner context
hcloud context create legal-rag 2>/dev/null || hcloud context use legal-rag
hcloud context active

echo -e "${GREEN}✓ Hetzner CLI configured${NC}"

# Step 4: Create SSH config for easy access
echo -e "${YELLOW}Step 4: Setting up SSH configuration...${NC}"

# Create SSH config entry
SSH_CONFIG_ENTRY="
# LegalTracking RAG System - Hetzner Server
Host legalrag
    HostName $SERVER_IP
    User root
    Port 22
    IdentityFile $(realpath $SSH_PRIVATE_KEY_PATH)
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
"

# Check if entry already exists
if ! grep -q "Host legalrag" ~/.ssh/config 2>/dev/null; then
    mkdir -p ~/.ssh
    echo "$SSH_CONFIG_ENTRY" >> ~/.ssh/config
    chmod 600 ~/.ssh/config
    echo -e "${GREEN}✓ SSH config created${NC}"
else
    echo -e "${GREEN}✓ SSH config already exists${NC}"
fi

# Step 5: Test SSH connection
echo -e "${YELLOW}Step 5: Testing SSH connection...${NC}"

if ssh -o ConnectTimeout=5 -i "$SSH_PRIVATE_KEY_PATH" root@$SERVER_IP "echo 'SSH connection successful'" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${YELLOW}Note: SSH connection test failed. This is normal if the server is still being set up.${NC}"
fi

# Step 6: Create helper scripts
echo -e "${YELLOW}Step 6: Creating helper scripts...${NC}"

# Create connect script
cat > connect-legalrag.sh << 'EOF'
#!/bin/bash
# Quick connect to LegalTracking RAG System
SERVER_IP="5.161.120.86"
SSH_KEY="./hetzner_key"

echo "Connecting to LegalTracking RAG System..."
ssh -i "$SSH_KEY" root@$SERVER_IP
EOF
chmod +x connect-legalrag.sh

# Create deploy script
cat > deploy-legalrag.sh << 'DEPLOY_SCRIPT'
#!/bin/bash
# Automated deployment to LegalTracking RAG System

set -e

SERVER_IP="5.161.120.86"
SSH_KEY="./hetzner_key"

echo "🚀 Deploying to LegalTracking RAG System..."

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "⚠️  Warning: .env file not found. Creating from template..."
    cp .env.example .env 2>/dev/null || cat > .env << 'ENV'
DEEPSEEK_API_KEY=your_deepseek_key
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
MILVUS_HOST=localhost
MILVUS_PORT=19530
OPENROUTER_API_KEY=your_openrouter_key
APP_ENV=production
ENV
    echo "Please edit .env with your actual API keys before deploying!"
    exit 1
fi

# Create deployment archive
echo "📦 Creating deployment package..."
tar czf deploy.tar.gz \
    Dockerfile \
    docker-compose.yml \
    nginx.conf \
    default.conf \
    .dockerignore \
    .env \
    lib/ \
    web/ \
    pubspec.yaml \
    pubspec.lock \
    --exclude=build \
    --exclude=.dart_tool \
    2>/dev/null || echo "Some files not found, continuing..."

# Upload to server
echo "📤 Uploading to server..."
scp -i "$SSH_KEY" deploy.tar.gz root@$SERVER_IP:/opt/legal-rag-mexico/

# Deploy on server
echo "🔧 Deploying application..."
ssh -i "$SSH_KEY" root@$SERVER_IP << 'REMOTE_DEPLOY'
cd /opt/legal-rag-mexico
tar xzf deploy.tar.gz
docker compose down
docker compose build
docker compose up -d
docker compose ps
echo "✅ Deployment complete!"
REMOTE_DEPLOY

# Cleanup
rm deploy.tar.gz

echo "✅ Deployment successful!"
echo "🌐 Access your application at: http://$SERVER_IP"
DEPLOY_SCRIPT
chmod +x deploy-legalrag.sh

# Create monitoring script
cat > monitor-legalrag.sh << 'MONITOR_SCRIPT'
#!/bin/bash
# Monitor LegalTracking RAG System

SERVER_IP="5.161.120.86"
SSH_KEY="./hetzner_key"

echo "📊 Monitoring LegalTracking RAG System..."
echo "================================================"

# Server stats
echo "🖥️  Server Status:"
ssh -i "$SSH_KEY" root@$SERVER_IP << 'MONITOR'
echo "Uptime: $(uptime)"
echo ""
echo "📊 Resource Usage:"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% used"
echo "Memory: $(free -h | grep Mem | awk '{print $3 " / " $2}')"
echo "Disk: $(df -h /mnt/data | tail -1 | awk '{print $3 " / " $2 " (" $5 " used)"}')"
echo ""
echo "🐳 Docker Status:"
cd /opt/legal-rag-mexico 2>/dev/null && docker compose ps || echo "Docker not running"
echo ""
echo "📈 Network:"
echo "Active connections: $(netstat -an | grep ESTABLISHED | wc -l)"
MONITOR

echo "================================================"
echo "View logs: ssh -i $SSH_KEY root@$SERVER_IP 'docker compose logs -f'"
MONITOR_SCRIPT
chmod +x monitor-legalrag.sh

echo -e "${GREEN}✓ Helper scripts created${NC}"

# Step 7: Create Hetzner CLI shortcuts
echo -e "${YELLOW}Step 7: Creating Hetzner CLI shortcuts...${NC}"

cat > hcloud-legalrag.sh << 'HCLOUD_SCRIPT'
#!/bin/bash
# Hetzner Cloud CLI shortcuts for LegalTracking RAG System

SERVER_NAME="LegalTracking-Rag-System"

case "$1" in
    status)
        echo "📊 Server Status:"
        hcloud server describe $SERVER_NAME
        ;;
    restart)
        echo "🔄 Restarting server..."
        hcloud server reboot $SERVER_NAME
        ;;
    poweroff)
        echo "⏹️  Powering off server..."
        hcloud server poweroff $SERVER_NAME
        ;;
    poweron)
        echo "▶️  Powering on server..."
        hcloud server poweron $SERVER_NAME
        ;;
    backup)
        echo "💾 Creating backup..."
        hcloud server create-image $SERVER_NAME --description "Backup $(date +%Y%m%d_%H%M%S)"
        ;;
    metrics)
        echo "📈 Server Metrics:"
        hcloud server metrics $SERVER_NAME --type cpu --start -1h
        hcloud server metrics $SERVER_NAME --type disk --start -1h
        hcloud server metrics $SERVER_NAME --type network --start -1h
        ;;
    firewall)
        echo "🔒 Firewall Rules:"
        hcloud firewall describe legal-rag-firewall 2>/dev/null || echo "No firewall configured"
        ;;
    *)
        echo "Usage: $0 {status|restart|poweroff|poweron|backup|metrics|firewall}"
        exit 1
        ;;
esac
HCLOUD_SCRIPT
chmod +x hcloud-legalrag.sh

echo -e "${GREEN}✓ Hetzner CLI shortcuts created${NC}"

# Step 8: Summary
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ SETUP COMPLETE!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Server Details:${NC}"
echo "  Name: $SERVER_NAME"
echo "  IPv4: $SERVER_IP"
echo "  IPv6: $SERVER_IPV6"
echo "  SSH Key: $SSH_KEY_PATH"
echo ""
echo -e "${BLUE}Quick Commands:${NC}"
echo "  Connect:     ./connect-legalrag.sh"
echo "  Deploy:      ./deploy-legalrag.sh"
echo "  Monitor:     ./monitor-legalrag.sh"
echo "  SSH Config:  ssh legalrag"
echo ""
echo -e "${BLUE}Hetzner CLI:${NC}"
echo "  Status:      ./hcloud-legalrag.sh status"
echo "  Restart:     ./hcloud-legalrag.sh restart"
echo "  Backup:      ./hcloud-legalrag.sh backup"
echo "  Metrics:     ./hcloud-legalrag.sh metrics"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Connect to server: ./connect-legalrag.sh"
echo "2. Run server setup: ./setup-legaltracking-server.sh"
echo "3. Deploy application: ./deploy-legalrag.sh"
echo ""
echo -e "${GREEN}================================================${NC}"

# Export server details for other scripts
export LEGALRAG_SERVER_IP="$SERVER_IP"
export LEGALRAG_SERVER_NAME="$SERVER_NAME"
export LEGALRAG_SSH_KEY="$SSH_PRIVATE_KEY_PATH"

echo -e "${YELLOW}Environment variables set for current session.${NC}"