#!/bin/bash

# =====================================================
# LegalTracking RAG System - Hetzner Server Setup
# Server: ccx13 (2 vCPU, 8GB RAM, 80GB + 250GB Volume)
# Location: Ashburn, VA (us-east)
# =====================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
source hetzner-config.env

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}LegalTracking RAG System - Server Setup${NC}"
echo -e "${BLUE}Server: ${SERVER_NAME} (${SERVER_TYPE})${NC}"
echo -e "${BLUE}================================================${NC}"

# Step 1: Get Server IP from Hetzner Console
echo -e "${YELLOW}Step 1: Server Connection${NC}"
echo -e "${GREEN}Please get your server IP from Hetzner Cloud Console${NC}"
echo -e "Your server name: ${SERVER_NAME}"
read -p "Enter your server IPv4 address: " SERVER_IP

# Save the IP for future use
echo "SERVER_IPV4=\"$SERVER_IP\"" >> hetzner-config.env

echo -e "${GREEN}✓ Server IP saved: $SERVER_IP${NC}"

# Step 2: Initial SSH Connection
echo -e "${YELLOW}Step 2: Connecting to server...${NC}"
echo -e "${GREEN}You'll now be connected to your server to run the setup${NC}"
echo -e "${GREEN}Copy and paste the following commands:${NC}"

cat << 'SETUP_SCRIPT'
# =====================================================
# RUN THESE COMMANDS ON YOUR HETZNER SERVER
# =====================================================

# Update system
apt-get update && apt-get upgrade -y

# Set timezone to US Eastern
timedatectl set-timezone America/New_York

# Install essential packages
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    ufw \
    fail2ban \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Setup the 250GB Volume
echo "Setting up 250GB volume..."

# Find the volume device (usually /dev/sdb)
VOLUME_DEVICE=$(lsblk -d -o NAME,SIZE | grep "250G" | awk '{print "/dev/"$1}')

if [ -z "$VOLUME_DEVICE" ]; then
    echo "Volume not found. Please check Hetzner console."
    exit 1
fi

echo "Found volume at: $VOLUME_DEVICE"

# Format the volume with ext4 if not already formatted
if ! blkid $VOLUME_DEVICE; then
    echo "Formatting volume..."
    mkfs.ext4 $VOLUME_DEVICE
fi

# Create mount point
mkdir -p /mnt/data

# Mount the volume
mount $VOLUME_DEVICE /mnt/data

# Add to fstab for permanent mounting
VOLUME_UUID=$(blkid -s UUID -o value $VOLUME_DEVICE)
echo "UUID=$VOLUME_UUID /mnt/data ext4 defaults,nofail 0 0" >> /etc/fstab

# Create data directories on the volume
mkdir -p /mnt/data/{docker,postgres,redis,milvus,app,uploads,backups,logs}

echo "✓ Volume mounted at /mnt/data"

# Setup swap file (4GB for better performance)
echo "Setting up 4GB swap..."
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Optimize swappiness for application server
echo 'vm.swappiness=10' >> /etc/sysctl.conf
sysctl -p

echo "✓ Swap configured"

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Configure Docker to use the volume for storage
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
    "data-root": "/mnt/data/docker",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "5"
    },
    "storage-driver": "overlay2"
}
EOF

systemctl restart docker
docker --version

echo "✓ Docker installed and configured"

# Install Docker Compose
echo "Installing Docker Compose..."
apt-get update
apt-get install -y docker-compose-plugin
docker compose version

echo "✓ Docker Compose installed"

# Setup UFW Firewall
echo "Configuring firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 3000/tcp  # Grafana (optional)
ufw reload

echo "✓ Firewall configured"

# Install Nginx
echo "Installing Nginx..."
apt-get install -y nginx certbot python3-certbot-nginx

# Create application directory
mkdir -p /opt/legal-rag-mexico
cd /opt/legal-rag-mexico

echo "✓ Nginx installed"

# Setup fail2ban for security
echo "Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl restart fail2ban

echo "✓ Security configured"

# System performance tuning
echo "Optimizing system performance..."
cat >> /etc/sysctl.conf <<EOF
# Network optimizations
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 65536
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535

# Memory optimizations
vm.overcommit_memory = 1
EOF

sysctl -p

echo "✓ System optimized"

# Create deployment user (optional)
echo "Creating deployment user..."
useradd -m -s /bin/bash deploy
usermod -aG docker deploy

# Setup monitoring
echo "Setting up basic monitoring..."
apt-get install -y prometheus-node-exporter

echo "✓ Basic monitoring installed"

# Summary
echo ""
echo "================================================"
echo "✅ SERVER SETUP COMPLETE!"
echo "================================================"
echo "Server: ccx13 (2 vCPU, 8GB RAM)"
echo "Storage: 80GB system + 250GB data volume"
echo "Volume mounted at: /mnt/data"
echo "Docker data: /mnt/data/docker"
echo "Swap: 4GB configured"
echo ""
echo "Security:"
echo "- UFW firewall enabled"
echo "- Fail2ban configured"
echo "- SSH on port 22"
echo ""
echo "Next steps:"
echo "1. Exit the server (type 'exit')"
echo "2. Run the deployment script"
echo "================================================"

SETUP_SCRIPT

echo ""
echo -e "${YELLOW}Now SSH into your server and run the setup:${NC}"
echo -e "${BLUE}ssh root@$SERVER_IP${NC}"
echo ""
echo -e "${GREEN}After connecting, copy and paste the commands above.${NC}"
echo ""
read -p "Press Enter after you've completed the server setup..."

# Step 3: Deploy the application
echo -e "${YELLOW}Step 3: Deploying application...${NC}"

# Create deployment package
echo "Creating deployment package..."
tar czf deployment.tar.gz \
    Dockerfile \
    docker-compose.yml \
    nginx.conf \
    default.conf \
    .dockerignore \
    lib/ \
    web/ \
    pubspec.yaml \
    pubspec.lock \
    --exclude=build \
    --exclude=.dart_tool

# Copy deployment files to server
echo "Copying files to server..."
scp deployment.tar.gz root@$SERVER_IP:/opt/legal-rag-mexico/
scp hetzner-config.env root@$SERVER_IP:/opt/legal-rag-mexico/

# Deploy on server
ssh root@$SERVER_IP << 'DEPLOY'
cd /opt/legal-rag-mexico

# Extract files
tar xzf deployment.tar.gz

# Load configuration
source hetzner-config.env

# Create .env file for Docker
cat > .env << EOF
# API Keys (UPDATE THESE!)
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-your_deepseek_key}
SUPABASE_URL=${SUPABASE_URL:-your_supabase_url}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-your_supabase_anon_key}
MILVUS_HOST=${MILVUS_HOST:-localhost}
MILVUS_PORT=${MILVUS_PORT:-19530}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-your_openrouter_key}

# Application
APP_ENV=production
APP_PORT=80

# Paths using the volume
DATA_PATH=/mnt/data
UPLOAD_PATH=/mnt/data/uploads
BACKUP_PATH=/mnt/data/backups
LOG_PATH=/mnt/data/logs
EOF

echo "Building Docker images..."
docker compose build

echo "Starting services..."
docker compose up -d

# Wait for services to start
sleep 10

# Check status
docker compose ps

echo "✓ Application deployed"
DEPLOY

# Step 4: Setup domain and SSL (optional)
echo -e "${YELLOW}Step 4: Domain Setup${NC}"
read -p "Do you have a domain to configure? (y/n): " SETUP_DOMAIN

if [[ $SETUP_DOMAIN =~ ^[Yy]$ ]]; then
    read -p "Enter your domain name (e.g., legaltracking-rag.com): " DOMAIN
    
    ssh root@$SERVER_IP << DOMAIN_SETUP
    # Setup Nginx proxy
    cat > /etc/nginx/sites-available/legal-rag << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/legal-rag /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    
    # Get SSL certificate
    certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
    
    echo "✓ Domain and SSL configured"
DOMAIN_SETUP
fi

# Step 5: Setup backups
echo -e "${YELLOW}Step 5: Setting up automated backups...${NC}"

ssh root@$SERVER_IP << 'BACKUP_SETUP'
# Create backup script
cat > /opt/backup-legaltracking.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/mnt/data/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Backup Docker volumes
cd /opt/legal-rag-mexico
docker compose exec -T postgres pg_dump -U postgres > $BACKUP_DIR/postgres_$DATE.sql 2>/dev/null || true
docker run --rm -v legal-rag-mexico_redis-data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/redis_$DATE.tar.gz -C /data .

# Backup application data
tar czf $BACKUP_DIR/app_data_$DATE.tar.gz -C /mnt/data app uploads

# Keep only last 7 days
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /opt/backup-legaltracking.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/backup-legaltracking.sh >> /mnt/data/logs/backup.log 2>&1") | crontab -

echo "✓ Automated backups configured"
BACKUP_SETUP

# Final Summary
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}🎉 DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Server Details:${NC}"
echo "  Name: LegalTracking-Rag-System"
echo "  Type: ccx13 (2 vCPU, 8GB RAM)"
echo "  Location: Ashburn, VA"
echo "  IP: $SERVER_IP"
echo "  Storage: 80GB + 250GB volume"
echo ""
echo -e "${BLUE}Application:${NC}"
echo "  URL: http://$SERVER_IP"
if [[ $SETUP_DOMAIN =~ ^[Yy]$ ]]; then
    echo "  Domain: https://$DOMAIN"
fi
echo ""
echo -e "${BLUE}Monitoring:${NC}"
echo "  Logs: docker compose logs -f"
echo "  Status: docker compose ps"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Update your .env file with actual API keys!${NC}"
echo "  SSH to server: ssh root@$SERVER_IP"
echo "  Edit: nano /opt/legal-rag-mexico/.env"
echo ""
echo -e "${GREEN}Monthly cost: \$14.49${NC}"
echo -e "${GREEN}================================================${NC}"