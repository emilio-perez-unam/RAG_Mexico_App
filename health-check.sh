#!/bin/bash

# =====================================================
# Health Check Script for LegalTracking RAG System
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
APP_NAME="LegalTracking RAG System"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🏥 Health Check - $APP_NAME${NC}"
echo -e "${BLUE}================================================${NC}"

# Function to check service
check_service() {
    local service_name=$1
    local check_command=$2
    local is_remote=${3:-false}
    
    echo -n "Checking $service_name... "
    
    if [ "$is_remote" = true ]; then
        if ssh -o ConnectTimeout=5 -i "$SSH_KEY" root@$SERVER_IP "$check_command" &>/dev/null; then
            echo -e "${GREEN}✓ Healthy${NC}"
            return 0
        else
            echo -e "${RED}✗ Unhealthy${NC}"
            return 1
        fi
    else
        if eval "$check_command" &>/dev/null; then
            echo -e "${GREEN}✓ Healthy${NC}"
            return 0
        else
            echo -e "${RED}✗ Unhealthy${NC}"
            return 1
        fi
    fi
}

# Check SSH connectivity
echo -e "${YELLOW}1. Connectivity Check${NC}"
check_service "SSH Connection" "echo 'test'" true

# Check server resources
echo -e "\n${YELLOW}2. Server Resources${NC}"
ssh -i "$SSH_KEY" root@$SERVER_IP 'bash -s' << 'RESOURCE_CHECK'
# CPU Usage
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
echo -n "CPU Usage: "
if (( $(echo "$cpu_usage < 80" | bc -l) )); then
    echo -e "\033[0;32m${cpu_usage}% ✓\033[0m"
else
    echo -e "\033[0;31m${cpu_usage}% ✗ High\033[0m"
fi

# Memory Usage
mem_info=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
echo -n "Memory Usage: "
if (( $(echo "$mem_info < 80" | bc -l) )); then
    echo -e "\033[0;32m${mem_info}% ✓\033[0m"
else
    echo -e "\033[0;31m${mem_info}% ✗ High\033[0m"
fi

# Disk Usage (System)
disk_usage=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
echo -n "System Disk Usage: "
if [ "$disk_usage" -lt 80 ]; then
    echo -e "\033[0;32m${disk_usage}% ✓\033[0m"
else
    echo -e "\033[0;31m${disk_usage}% ✗ High\033[0m"
fi

# Disk Usage (Data Volume)
if [ -d /mnt/data ]; then
    data_usage=$(df -h /mnt/data | awk 'NR==2{print $5}' | sed 's/%//')
    echo -n "Data Volume Usage: "
    if [ "$data_usage" -lt 80 ]; then
        echo -e "\033[0;32m${data_usage}% ✓\033[0m"
    else
        echo -e "\033[0;31m${data_usage}% ✗ High\033[0m"
    fi
fi

# Swap Usage
swap_info=$(free -m | awk 'NR==3{if($2>0) printf "%.1f", $3*100/$2; else print "0"}')
echo -n "Swap Usage: "
echo -e "\033[0;32m${swap_info}% ✓\033[0m"
RESOURCE_CHECK

# Check Docker services
echo -e "\n${YELLOW}3. Docker Services${NC}"
ssh -i "$SSH_KEY" root@$SERVER_IP 'bash -s' << 'DOCKER_CHECK'
cd /opt/legal-rag-mexico 2>/dev/null || exit 0

if [ -f docker-compose.yml ]; then
    # Check if Docker is running
    if ! systemctl is-active docker &>/dev/null; then
        echo -e "\033[0;31mDocker service is not running ✗\033[0m"
        exit 1
    fi
    
    # Get container status
    containers=$(docker compose ps --format json 2>/dev/null || echo "[]")
    
    # Check web service
    if docker compose ps | grep -q "legal-rag-web.*running"; then
        echo -e "Web Service: \033[0;32m✓ Running\033[0m"
    else
        echo -e "Web Service: \033[0;31m✗ Not running\033[0m"
    fi
    
    # Check database services if configured
    if docker compose ps | grep -q "postgres.*running"; then
        echo -e "PostgreSQL: \033[0;32m✓ Running\033[0m"
    fi
    
    if docker compose ps | grep -q "redis.*running"; then
        echo -e "Redis: \033[0;32m✓ Running\033[0m"
    fi
    
    if docker compose ps | grep -q "milvus.*running"; then
        echo -e "Milvus: \033[0;32m✓ Running\033[0m"
    fi
else
    echo -e "\033[1;33mDocker Compose not configured\033[0m"
fi
DOCKER_CHECK

# Check application endpoints
echo -e "\n${YELLOW}4. Application Endpoints${NC}"

# Main application
echo -n "Main Application (HTTP): "
if curl -sf -o /dev/null -w "%{http_code}" "http://$SERVER_IP" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ Responding${NC}"
else
    echo -e "${RED}✗ Not responding${NC}"
fi

# Health endpoint
echo -n "Health Endpoint: "
if curl -sf "http://$SERVER_IP/health" &>/dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${YELLOW}⚠ Not configured${NC}"
fi

# Check HTTPS if certificate exists
echo -n "HTTPS: "
if curl -sf -o /dev/null -w "%{http_code}" "https://$SERVER_IP" 2>/dev/null | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ SSL Active${NC}"
else
    echo -e "${YELLOW}⚠ SSL not configured${NC}"
fi

# Check Nginx
echo -e "\n${YELLOW}5. Web Server${NC}"
ssh -i "$SSH_KEY" root@$SERVER_IP 'bash -s' << 'NGINX_CHECK'
# Check Nginx status
if systemctl is-active nginx &>/dev/null; then
    echo -e "Nginx: \033[0;32m✓ Running\033[0m"
    
    # Check Nginx config
    if nginx -t &>/dev/null; then
        echo -e "Nginx Config: \033[0;32m✓ Valid\033[0m"
    else
        echo -e "Nginx Config: \033[0;31m✗ Invalid\033[0m"
    fi
else
    echo -e "Nginx: \033[1;33m⚠ Not running\033[0m"
fi
NGINX_CHECK

# Check security
echo -e "\n${YELLOW}6. Security${NC}"
ssh -i "$SSH_KEY" root@$SERVER_IP 'bash -s' << 'SECURITY_CHECK'
# UFW Firewall
if ufw status | grep -q "Status: active"; then
    echo -e "Firewall (UFW): \033[0;32m✓ Active\033[0m"
else
    echo -e "Firewall (UFW): \033[0;31m✗ Inactive\033[0m"
fi

# Fail2ban
if systemctl is-active fail2ban &>/dev/null; then
    echo -e "Fail2ban: \033[0;32m✓ Active\033[0m"
else
    echo -e "Fail2ban: \033[1;33m⚠ Inactive\033[0m"
fi

# Check for security updates
updates=$(apt list --upgradable 2>/dev/null | grep -c "security" || echo "0")
if [ "$updates" -eq 0 ]; then
    echo -e "Security Updates: \033[0;32m✓ System up to date\033[0m"
else
    echo -e "Security Updates: \033[1;33m⚠ $updates security updates available\033[0m"
fi
SECURITY_CHECK

# Check backups
echo -e "\n${YELLOW}7. Backup Status${NC}"
ssh -i "$SSH_KEY" root@$SERVER_IP 'bash -s' << 'BACKUP_CHECK'
BACKUP_DIR="/mnt/data/backups"
if [ -d "$BACKUP_DIR" ]; then
    backup_count=$(find $BACKUP_DIR -type f -name "*.tar.gz" -o -name "*.sql" 2>/dev/null | wc -l)
    latest_backup=$(find $BACKUP_DIR -type f \( -name "*.tar.gz" -o -name "*.sql" \) -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    
    if [ "$backup_count" -gt 0 ]; then
        echo -e "Backup Files: \033[0;32m✓ $backup_count backups found\033[0m"
        if [ -n "$latest_backup" ]; then
            backup_age=$(( ($(date +%s) - $(stat -c %Y "$latest_backup")) / 86400 ))
            if [ "$backup_age" -le 1 ]; then
                echo -e "Latest Backup: \033[0;32m✓ Less than 24 hours old\033[0m"
            else
                echo -e "Latest Backup: \033[1;33m⚠ $backup_age days old\033[0m"
            fi
        fi
    else
        echo -e "Backup Files: \033[1;33m⚠ No backups found\033[0m"
    fi
else
    echo -e "Backup Directory: \033[0;31m✗ Not configured\033[0m"
fi

# Check if backup cron is configured
if crontab -l 2>/dev/null | grep -q "backup-legaltracking.sh"; then
    echo -e "Backup Schedule: \033[0;32m✓ Automated backups configured\033[0m"
else
    echo -e "Backup Schedule: \033[1;33m⚠ No automated backups\033[0m"
fi
BACKUP_CHECK

# Network connectivity tests
echo -e "\n${YELLOW}8. Network Connectivity${NC}"
echo -n "DNS Resolution: "
if ssh -i "$SSH_KEY" root@$SERVER_IP "nslookup google.com &>/dev/null"; then
    echo -e "${GREEN}✓ Working${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

echo -n "External Connectivity: "
if ssh -i "$SSH_KEY" root@$SERVER_IP "ping -c 1 8.8.8.8 &>/dev/null"; then
    echo -e "${GREEN}✓ Working${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

# Application logs check
echo -e "\n${YELLOW}9. Recent Logs${NC}"
echo "Checking for errors in recent logs..."
ssh -i "$SSH_KEY" root@$SERVER_IP 'bash -s' << 'LOG_CHECK'
cd /opt/legal-rag-mexico 2>/dev/null || exit 0

if [ -f docker-compose.yml ]; then
    error_count=$(docker compose logs --tail=100 2>/dev/null | grep -ciE "error|exception|failed|critical" || echo "0")
    warning_count=$(docker compose logs --tail=100 2>/dev/null | grep -ciE "warning|warn" || echo "0")
    
    if [ "$error_count" -eq 0 ]; then
        echo -e "Errors: \033[0;32m✓ No recent errors\033[0m"
    else
        echo -e "Errors: \033[1;33m⚠ $error_count errors in recent logs\033[0m"
    fi
    
    if [ "$warning_count" -eq 0 ]; then
        echo -e "Warnings: \033[0;32m✓ No recent warnings\033[0m"
    else
        echo -e "Warnings: \033[0;34mℹ $warning_count warnings in recent logs\033[0m"
    fi
fi
LOG_CHECK

# Performance metrics
echo -e "\n${YELLOW}10. Performance Metrics${NC}"
ssh -i "$SSH_KEY" root@$SERVER_IP 'bash -s' << 'PERFORMANCE_CHECK'
# Check load average
load_avg=$(uptime | awk -F'load average:' '{print $2}')
echo "Load Average:$load_avg"

# Check response time
response_time=$(curl -o /dev/null -s -w "%{time_total}" http://localhost 2>/dev/null || echo "N/A")
if [ "$response_time" != "N/A" ]; then
    response_ms=$(echo "$response_time * 1000" | bc | cut -d'.' -f1)
    echo -n "Response Time: "
    if [ "$response_ms" -lt 1000 ]; then
        echo -e "\033[0;32m${response_ms}ms ✓\033[0m"
    elif [ "$response_ms" -lt 3000 ]; then
        echo -e "\033[1;33m${response_ms}ms ⚠ Slow\033[0m"
    else
        echo -e "\033[0;31m${response_ms}ms ✗ Very slow\033[0m"
    fi
fi

# Active connections
active_connections=$(netstat -an | grep -c ESTABLISHED 2>/dev/null || echo "0")
echo -e "Active Connections: \033[0;32m$active_connections\033[0m"
PERFORMANCE_CHECK

# Summary
echo -e "\n${BLUE}================================================${NC}"
echo -e "${BLUE}Health Check Summary${NC}"
echo -e "${BLUE}================================================${NC}"

# Calculate overall health
ssh -i "$SSH_KEY" root@$SERVER_IP 'bash -s' << 'SUMMARY'
issues=0
warnings=0

# Count critical issues
if ! systemctl is-active docker &>/dev/null; then ((issues++)); fi
if ! docker compose ps 2>/dev/null | grep -q "running"; then ((issues++)); fi
if ! curl -sf http://localhost &>/dev/null; then ((issues++)); fi

# Count warnings
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
if (( $(echo "$cpu_usage > 80" | bc -l) )); then ((warnings++)); fi

mem_info=$(free -m | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ "$mem_info" -gt 80 ]; then ((warnings++)); fi

if [ "$issues" -eq 0 ] && [ "$warnings" -eq 0 ]; then
    echo -e "\033[0;32m✅ SYSTEM HEALTHY - All checks passed\033[0m"
elif [ "$issues" -eq 0 ] && [ "$warnings" -gt 0 ]; then
    echo -e "\033[1;33m⚠️  SYSTEM OPERATIONAL - $warnings warnings detected\033[0m"
else
    echo -e "\033[0;31m❌ SYSTEM UNHEALTHY - $issues critical issues detected\033[0m"
fi

echo ""
echo "Server: LegalTracking-Rag-System"
echo "IP: 5.161.120.86"
echo "Time: $(date)"
SUMMARY

echo -e "${BLUE}================================================${NC}"