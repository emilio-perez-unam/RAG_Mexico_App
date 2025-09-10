#!/bin/bash

# =====================================================
# SSL Certificate Setup for LegalTracking RAG System
# Using Let's Encrypt with Certbot
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

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🔒 SSL Certificate Setup${NC}"
echo -e "${BLUE}================================================${NC}"

# Get domain information
echo -e "${YELLOW}Domain Configuration${NC}"
echo -e "${GREEN}Please enter your domain information:${NC}"
read -p "Enter your domain name (e.g., legaltracking.com): " DOMAIN
read -p "Enter your email for SSL notifications: " EMAIL

# Validate domain
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: Domain name is required${NC}"
    exit 1
fi

if [ -z "$EMAIL" ]; then
    echo -e "${RED}Error: Email is required for Let's Encrypt${NC}"
    exit 1
fi

# Check DNS
echo -e "${YELLOW}Checking DNS configuration...${NC}"
DNS_IP=$(dig +short "$DOMAIN" | head -n1)

if [ "$DNS_IP" = "$SERVER_IP" ]; then
    echo -e "${GREEN}✓ DNS is correctly configured${NC}"
else
    echo -e "${YELLOW}⚠ DNS Check Result:${NC}"
    echo "  Expected IP: $SERVER_IP"
    echo "  Current DNS: ${DNS_IP:-Not configured}"
    echo ""
    echo -e "${YELLOW}Please ensure your domain's A record points to: $SERVER_IP${NC}"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Setup SSL on server
echo -e "${YELLOW}Configuring SSL on server...${NC}"

ssh -i "$SSH_KEY" root@$SERVER_IP << REMOTE_SSL
set -e

# Colors for remote
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\${BLUE}Setting up SSL for $DOMAIN\${NC}"

# Install certbot if not installed
if ! command -v certbot &> /dev/null; then
    echo "Installing Certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Stop any service using port 80 temporarily
echo "Preparing for certificate generation..."
systemctl stop nginx 2>/dev/null || true

# Create webroot directory
mkdir -p /var/www/certbot

# Configure Nginx for the domain (HTTP first)
cat > /etc/nginx/sites-available/$DOMAIN << 'NGINX_HTTP'
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # For Let's Encrypt validation
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Max upload size
        client_max_body_size 100M;
    }
}
NGINX_HTTP

# Replace $DOMAIN placeholder
sed -i "s/\$DOMAIN/$DOMAIN/g" /etc/nginx/sites-available/$DOMAIN

# Enable the site
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Start Nginx
systemctl start nginx
nginx -t && systemctl reload nginx

echo -e "\${GREEN}✓ Nginx configured for HTTP\${NC}"

# Get SSL certificate
echo -e "\${YELLOW}Requesting SSL certificate from Let's Encrypt...\${NC}"

# Try to get certificate
certbot certonly \
    --webroot \
    --webroot-path /var/www/certbot \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --domains $DOMAIN \
    --domains www.$DOMAIN \
    2>&1 | tee /tmp/certbot.log

if [ \$? -eq 0 ]; then
    echo -e "\${GREEN}✓ SSL certificate obtained successfully\${NC}"
else
    echo -e "\${RED}Failed to obtain certificate. Check /tmp/certbot.log\${NC}"
    exit 1
fi

# Configure Nginx with SSL
echo -e "\${YELLOW}Configuring Nginx with SSL...\${NC}"

cat > /etc/nginx/sites-available/$DOMAIN << 'NGINX_SSL'
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Max upload size
    client_max_body_size 100M;
    
    # Proxy to application
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
NGINX_SSL

# Replace $DOMAIN placeholder
sed -i "s/\$DOMAIN/$DOMAIN/g" /etc/nginx/sites-available/$DOMAIN

# Test and reload Nginx
nginx -t && systemctl reload nginx

echo -e "\${GREEN}✓ Nginx configured with SSL\${NC}"

# Setup auto-renewal
echo -e "\${YELLOW}Setting up automatic certificate renewal...\${NC}"

# Create renewal script
cat > /etc/cron.d/certbot << 'CRON'
# Renew certificates twice daily
0 3,15 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
CRON

# Test renewal
certbot renew --dry-run

echo -e "\${GREEN}✓ Auto-renewal configured\${NC}"

# Update firewall
echo -e "\${YELLOW}Updating firewall rules...\${NC}"
ufw allow 443/tcp
ufw reload

echo -e "\${GREEN}✓ Firewall updated\${NC}"

# Create SSL monitoring script
cat > /opt/check-ssl.sh << 'SSL_CHECK'
#!/bin/bash
# Check SSL certificate expiration

DOMAIN="$DOMAIN"
DAYS_WARNING=30

expiry_date=\$(echo | openssl s_client -servername \$DOMAIN -connect \$DOMAIN:443 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
expiry_epoch=\$(date -d "\$expiry_date" +%s)
current_epoch=\$(date +%s)
days_left=\$(( (\$expiry_epoch - \$current_epoch) / 86400 ))

if [ \$days_left -lt \$DAYS_WARNING ]; then
    echo "WARNING: SSL certificate expires in \$days_left days"
    # Could add email notification here
else
    echo "SSL certificate valid for \$days_left more days"
fi
SSL_CHECK

sed -i "s/\$DOMAIN/$DOMAIN/g" /opt/check-ssl.sh
chmod +x /opt/check-ssl.sh

# Add to monitoring cron
(crontab -l 2>/dev/null; echo "0 9 * * * /opt/check-ssl.sh >> /var/log/ssl-check.log 2>&1") | crontab -

echo ""
echo -e "\${GREEN}================================================\${NC}"
echo -e "\${GREEN}✅ SSL SETUP COMPLETE!\${NC}"
echo -e "\${GREEN}================================================\${NC}"
echo ""
echo "Domain: $DOMAIN"
echo "Certificate: /etc/letsencrypt/live/$DOMAIN/"
echo "Auto-renewal: Enabled (twice daily)"
echo "Monitoring: /opt/check-ssl.sh"
echo ""
echo -e "\${BLUE}Test your SSL configuration:\${NC}"
echo "  https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo ""
echo -e "\${GREEN}================================================\${NC}"

REMOTE_SSL

# Test the SSL setup
echo ""
echo -e "${YELLOW}Testing SSL configuration...${NC}"

# Test HTTPS
if curl -sf "https://$DOMAIN" &>/dev/null; then
    echo -e "${GREEN}✓ HTTPS is working${NC}"
else
    echo -e "${YELLOW}⚠ HTTPS test failed - this might be normal if DNS is still propagating${NC}"
fi

# Check certificate
echo ""
echo -e "${BLUE}Checking certificate details...${NC}"
echo | openssl s_client -servername "$DOMAIN" -connect "$SERVER_IP:443" 2>/dev/null | openssl x509 -noout -text | grep -A2 "Subject:"

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ SSL Setup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Your application is now available at:${NC}"
echo -e "  ${GREEN}https://$DOMAIN${NC}"
echo -e "  ${GREEN}https://www.$DOMAIN${NC}"
echo ""
echo -e "${BLUE}Certificate Information:${NC}"
echo "  Provider: Let's Encrypt"
echo "  Auto-renewal: Enabled"
echo "  Email: $EMAIL"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test your site: https://$DOMAIN"
echo "2. Check SSL rating: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo "3. Monitor certificate: ssh -i $SSH_KEY root@$SERVER_IP '/opt/check-ssl.sh'"
echo ""
echo -e "${GREEN}================================================${NC}"