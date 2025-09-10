#!/bin/bash

# =====================================================
# Legal RAG Mexico - Hetzner Cloud Deployment Script
# =====================================================
# This script automates deployment to Hetzner Cloud
# Prerequisites:
# - Hetzner Cloud CLI (hcloud) installed
# - Docker and Docker Compose on target server
# - SSH key configured for server access
# =====================================================

set -e  # Exit on error

# Configuration
APP_NAME="legal-rag-mexico"
DOMAIN="${DOMAIN:-legal-rag.example.com}"
SERVER_NAME="${SERVER_NAME:-legal-rag-prod}"
SERVER_TYPE="${SERVER_TYPE:-cx21}"  # 2 vCPU, 4GB RAM
SERVER_IMAGE="${SERVER_IMAGE:-ubuntu-22.04}"
SERVER_LOCATION="${SERVER_LOCATION:-nbg1}"  # Nuremberg, Germany
SSH_KEY_NAME="${SSH_KEY_NAME:-default}"
FIREWALL_NAME="${FIREWALL_NAME:-legal-rag-firewall}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if required tools are installed
check_requirements() {
    log_info "Checking requirements..."
    
    command -v hcloud >/dev/null 2>&1 || {
        log_error "Hetzner Cloud CLI (hcloud) is not installed. Install it from: https://github.com/hetznercloud/cli"
    }
    
    command -v docker >/dev/null 2>&1 || {
        log_warning "Docker is not installed locally. This is needed for building images."
    }
    
    command -v ssh >/dev/null 2>&1 || {
        log_error "SSH is not installed."
    }
    
    log_info "All requirements met!"
}

# Create Hetzner Cloud server
create_server() {
    log_info "Creating Hetzner Cloud server..."
    
    # Check if server already exists
    if hcloud server describe $SERVER_NAME >/dev/null 2>&1; then
        log_warning "Server $SERVER_NAME already exists. Skipping creation."
        return 0
    fi
    
    # Create the server
    hcloud server create \
        --name $SERVER_NAME \
        --type $SERVER_TYPE \
        --image $SERVER_IMAGE \
        --location $SERVER_LOCATION \
        --ssh-key $SSH_KEY_NAME \
        --label app=$APP_NAME \
        --label env=production
    
    log_info "Server created successfully!"
    
    # Wait for server to be ready
    log_info "Waiting for server to be ready..."
    sleep 30
}

# Create and attach firewall
setup_firewall() {
    log_info "Setting up firewall..."
    
    # Check if firewall exists
    if ! hcloud firewall describe $FIREWALL_NAME >/dev/null 2>&1; then
        # Create firewall
        hcloud firewall create --name $FIREWALL_NAME
        
        # Add rules
        hcloud firewall add-rule $FIREWALL_NAME \
            --direction in --source-ips 0.0.0.0/0 --protocol tcp --port 22
        
        hcloud firewall add-rule $FIREWALL_NAME \
            --direction in --source-ips 0.0.0.0/0 --protocol tcp --port 80
        
        hcloud firewall add-rule $FIREWALL_NAME \
            --direction in --source-ips 0.0.0.0/0 --protocol tcp --port 443
        
        hcloud firewall add-rule $FIREWALL_NAME \
            --direction out --destination-ips 0.0.0.0/0 --protocol tcp --port any
        
        hcloud firewall add-rule $FIREWALL_NAME \
            --direction out --destination-ips 0.0.0.0/0 --protocol udp --port any
    fi
    
    # Apply firewall to server
    hcloud firewall apply-to-resource $FIREWALL_NAME \
        --type server --server $SERVER_NAME || true
    
    log_info "Firewall configured!"
}

# Get server IP
get_server_ip() {
    SERVER_IP=$(hcloud server ip $SERVER_NAME)
    log_info "Server IP: $SERVER_IP"
}

# Setup server with Docker
setup_docker_on_server() {
    log_info "Setting up Docker on server..."
    
    ssh -o StrictHostKeyChecking=no root@$SERVER_IP << 'ENDSSH'
    # Update system
    apt-get update
    apt-get upgrade -y
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    
    # Install Docker Compose
    apt-get install -y docker-compose-plugin
    
    # Setup swap (helpful for smaller instances)
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    
    # Configure Docker
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "5"
    }
}
EOF
    
    systemctl restart docker
    
    # Install additional tools
    apt-get install -y git nginx certbot python3-certbot-nginx ufw fail2ban
    
    # Setup UFW firewall
    ufw --force enable
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Create app directory
    mkdir -p /opt/legal-rag-mexico
    
    echo "Docker setup complete!"
ENDSSH
    
    log_info "Docker installed on server!"
}

# Deploy application
deploy_app() {
    log_info "Deploying application..."
    
    # Create .env file from environment variables
    cat > .env.production << EOF
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
MILVUS_HOST=${MILVUS_HOST}
MILVUS_PORT=${MILVUS_PORT}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
APP_ENV=production
REDIS_PASSWORD=${REDIS_PASSWORD:-$(openssl rand -base64 32)}
GRAFANA_PASSWORD=${GRAFANA_PASSWORD:-$(openssl rand -base64 32)}
EOF
    
    # Copy files to server
    log_info "Copying files to server..."
    scp -r \
        Dockerfile \
        docker-compose.yml \
        nginx.conf \
        default.conf \
        .dockerignore \
        .env.production \
        root@$SERVER_IP:/opt/legal-rag-mexico/
    
    # Copy application code
    rsync -avz \
        --exclude='.git' \
        --exclude='build' \
        --exclude='.dart_tool' \
        --exclude='node_modules' \
        ./ root@$SERVER_IP:/opt/legal-rag-mexico/app/
    
    # Build and run on server
    ssh root@$SERVER_IP << 'ENDSSH'
    cd /opt/legal-rag-mexico
    
    # Load environment variables
    export $(cat .env.production | xargs)
    
    # Build the Docker image
    docker compose build
    
    # Start the services
    docker compose up -d
    
    # Check if services are running
    docker compose ps
    
    echo "Application deployed!"
ENDSSH
    
    log_info "Application deployed successfully!"
}

# Setup SSL with Let's Encrypt
setup_ssl() {
    log_info "Setting up SSL certificates..."
    
    ssh root@$SERVER_IP << ENDSSH
    # Stop nginx if running
    systemctl stop nginx || true
    
    # Get SSL certificate
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email admin@$DOMAIN \
        -d $DOMAIN \
        -d www.$DOMAIN
    
    # Create nginx configuration for SSL
    cat > /etc/nginx/sites-available/legal-rag << 'CONFEOF'
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
CONFEOF
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/legal-rag /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload nginx
    nginx -t
    systemctl restart nginx
    
    # Setup auto-renewal
    echo "0 0,12 * * * root certbot renew --quiet && systemctl reload nginx" >> /etc/crontab
    
    echo "SSL setup complete!"
ENDSSH
    
    log_info "SSL certificates installed!"
}

# Setup monitoring
setup_monitoring() {
    log_info "Setting up monitoring..."
    
    ssh root@$SERVER_IP << 'ENDSSH'
    cd /opt/legal-rag-mexico
    
    # Start monitoring services
    docker compose --profile monitoring up -d
    
    echo "Monitoring services started!"
ENDSSH
    
    log_info "Monitoring setup complete!"
}

# Setup backups
setup_backups() {
    log_info "Setting up automated backups..."
    
    ssh root@$SERVER_IP << 'ENDSSH'
    # Create backup script
    cat > /opt/backup.sh << 'BACKUPEOF'
#!/bin/bash
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Backup Docker volumes
docker run --rm \
    -v legal-rag-mexico_redis-data:/data \
    -v $BACKUP_DIR:/backup \
    alpine tar czf /backup/redis-data-$DATE.tar.gz -C /data .

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
BACKUPEOF
    
    chmod +x /opt/backup.sh
    
    # Add to crontab (daily at 2 AM)
    echo "0 2 * * * root /opt/backup.sh >> /var/log/backup.log 2>&1" >> /etc/crontab
    
    echo "Backup system configured!"
ENDSSH
    
    log_info "Backup system setup complete!"
}

# Health check
health_check() {
    log_info "Performing health check..."
    
    # Check if application is responding
    if curl -s -o /dev/null -w "%{http_code}" http://$SERVER_IP | grep -q "200"; then
        log_info "Application is running and healthy!"
    else
        log_warning "Application may not be responding correctly. Please check logs."
    fi
    
    # Show Docker status
    ssh root@$SERVER_IP "cd /opt/legal-rag-mexico && docker compose ps"
}

# Main deployment flow
main() {
    echo "================================================"
    echo "Legal RAG Mexico - Hetzner Deployment"
    echo "================================================"
    
    check_requirements
    
    # Check for required environment variables
    if [ -z "$DEEPSEEK_API_KEY" ] || [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
        log_error "Required environment variables are not set. Please set:
        - DEEPSEEK_API_KEY
        - SUPABASE_URL
        - SUPABASE_ANON_KEY"
    fi
    
    # Deployment steps
    create_server
    setup_firewall
    get_server_ip
    setup_docker_on_server
    deploy_app
    
    # Optional: Setup SSL if domain is provided
    if [ "$DOMAIN" != "legal-rag.example.com" ]; then
        setup_ssl
    fi
    
    # Optional: Setup monitoring
    read -p "Do you want to setup monitoring? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_monitoring
    fi
    
    setup_backups
    health_check
    
    echo "================================================"
    log_info "Deployment complete!"
    log_info "Server IP: $SERVER_IP"
    if [ "$DOMAIN" != "legal-rag.example.com" ]; then
        log_info "Application URL: https://$DOMAIN"
    else
        log_info "Application URL: http://$SERVER_IP"
    fi
    echo "================================================"
}

# Run main function
main "$@"