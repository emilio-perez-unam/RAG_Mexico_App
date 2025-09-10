#!/bin/bash

# =====================================================
# Rollback Script for LegalTracking RAG System
# Safely rollback to previous deployment version
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
APP_DIR="/opt/legal-rag-mexico"
BACKUP_DIR="/mnt/data/backups"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🔄 Deployment Rollback System${NC}"
echo -e "${BLUE}================================================${NC}"

# Function to list available backups
list_backups() {
    echo -e "${YELLOW}Fetching available backups...${NC}"
    
    ssh -i "$SSH_KEY" root@$SERVER_IP << 'LIST_BACKUPS'
    BACKUP_DIR="/mnt/data/backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "No backup directory found"
        exit 1
    fi
    
    echo "Available backups:"
    echo "=================="
    
    # List deployment backups
    find $BACKUP_DIR -name "deployment_*.tar.gz" -type f -printf "%T@ %Tc %s %p\n" 2>/dev/null | \
        sort -rn | \
        head -10 | \
        awk '{
            size=$3/1024/1024;
            printf "%d. %s %s %s %.2f MB\n", NR, $5, $6, $7, size;
            for(i=10; i<=NF; i++) printf " %s", $i;
            printf "\n"
        }'
LIST_BACKUPS
}

# Main menu
echo -e "${YELLOW}What would you like to do?${NC}"
echo "1. Quick rollback (to last backup)"
echo "2. Choose specific backup to restore"
echo "3. Emergency rollback (restore last known good state)"
echo "4. View current deployment info"
echo "5. Exit"
echo ""
read -p "Select option (1-5): " OPTION

case $OPTION in
    1)
        # Quick rollback to last backup
        echo -e "${YELLOW}Performing quick rollback to last backup...${NC}"
        
        ssh -i "$SSH_KEY" root@$SERVER_IP << 'QUICK_ROLLBACK'
        set -e
        
        BACKUP_DIR="/mnt/data/backups"
        APP_DIR="/opt/legal-rag-mexico"
        
        # Find the most recent backup
        LAST_BACKUP=$(find $BACKUP_DIR -name "deployment_*.tar.gz" -type f -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2)
        
        if [ -z "$LAST_BACKUP" ]; then
            echo "❌ No backup found to rollback to"
            exit 1
        fi
        
        echo "Found backup: $LAST_BACKUP"
        
        # Create rollback point of current deployment
        echo "Creating rollback point of current deployment..."
        cd $APP_DIR
        tar czf $BACKUP_DIR/rollback_$(date +%Y%m%d_%H%M%S).tar.gz . 2>/dev/null || true
        
        # Stop current services
        echo "Stopping current services..."
        docker compose down 2>/dev/null || true
        
        # Backup current deployment
        mv $APP_DIR ${APP_DIR}_rollback_$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
        mkdir -p $APP_DIR
        
        # Extract backup
        echo "Restoring from backup..."
        cd $APP_DIR
        tar xzf $LAST_BACKUP
        
        # Restore environment if needed
        if [ ! -f .env ] && [ -f $BACKUP_DIR/env_backup ]; then
            cp $BACKUP_DIR/env_backup .env
        fi
        
        # Rebuild and restart services
        echo "Rebuilding services..."
        docker compose build
        docker compose up -d
        
        # Wait for services
        sleep 10
        
        # Check health
        if curl -f http://localhost/health &>/dev/null; then
            echo "✅ Rollback successful!"
            docker compose ps
        else
            echo "⚠️  Services started but health check failed"
        fi
QUICK_ROLLBACK
        ;;
        
    2)
        # Choose specific backup
        list_backups
        echo ""
        read -p "Enter backup number to restore (or 0 to cancel): " BACKUP_NUM
        
        if [ "$BACKUP_NUM" -eq 0 ]; then
            echo "Rollback cancelled"
            exit 0
        fi
        
        ssh -i "$SSH_KEY" root@$SERVER_IP << SPECIFIC_ROLLBACK
        set -e
        
        BACKUP_DIR="/mnt/data/backups"
        APP_DIR="/opt/legal-rag-mexico"
        
        # Get the selected backup
        SELECTED_BACKUP=\$(find \$BACKUP_DIR -name "deployment_*.tar.gz" -type f -printf "%T@ %p\n" 2>/dev/null | \
            sort -rn | \
            head -$BACKUP_NUM | \
            tail -1 | \
            cut -d' ' -f2)
        
        if [ -z "\$SELECTED_BACKUP" ]; then
            echo "❌ Invalid backup selection"
            exit 1
        fi
        
        echo "Restoring from: \$SELECTED_BACKUP"
        
        # Create rollback point
        echo "Creating rollback point..."
        cd \$APP_DIR
        tar czf \$BACKUP_DIR/rollback_\$(date +%Y%m%d_%H%M%S).tar.gz . 2>/dev/null || true
        
        # Stop services
        docker compose down 2>/dev/null || true
        
        # Backup and restore
        mv \$APP_DIR \${APP_DIR}_rollback_\$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
        mkdir -p \$APP_DIR
        cd \$APP_DIR
        tar xzf \$SELECTED_BACKUP
        
        # Rebuild and start
        docker compose build
        docker compose up -d
        
        sleep 10
        
        if curl -f http://localhost/health &>/dev/null; then
            echo "✅ Rollback to selected backup successful!"
        else
            echo "⚠️  Services started but health check failed"
        fi
SPECIFIC_ROLLBACK
        ;;
        
    3)
        # Emergency rollback
        echo -e "${RED}⚠️  EMERGENCY ROLLBACK${NC}"
        echo "This will restore the last known good configuration"
        read -p "Are you sure? (yes/no): " CONFIRM
        
        if [ "$CONFIRM" != "yes" ]; then
            echo "Emergency rollback cancelled"
            exit 0
        fi
        
        ssh -i "$SSH_KEY" root@$SERVER_IP << 'EMERGENCY_ROLLBACK'
        set -e
        
        echo "Starting emergency rollback..."
        
        APP_DIR="/opt/legal-rag-mexico"
        BACKUP_DIR="/mnt/data/backups"
        
        # Stop everything
        echo "Stopping all services..."
        cd $APP_DIR 2>/dev/null || true
        docker compose down -v 2>/dev/null || true
        docker system prune -af 2>/dev/null || true
        
        # Find any working backup
        EMERGENCY_BACKUP=$(find $BACKUP_DIR -name "*.tar.gz" -type f -size +1M -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2)
        
        if [ -z "$EMERGENCY_BACKUP" ]; then
            echo "❌ No backup available for emergency restore"
            
            # Try to restore from git if available
            if [ -d "$APP_DIR/.git" ]; then
                echo "Attempting git restore..."
                cd $APP_DIR
                git reset --hard HEAD
                git clean -fd
            else
                echo "Creating minimal working configuration..."
                mkdir -p $APP_DIR
                cd $APP_DIR
                
                # Create minimal docker-compose
                cat > docker-compose.yml << 'MINIMAL'
version: '3.8'
services:
  maintenance:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./maintenance.html:/usr/share/nginx/html/index.html
    restart: unless-stopped
MINIMAL
                
                # Create maintenance page
                cat > maintenance.html << 'MAINTENANCE'
<!DOCTYPE html>
<html>
<head>
    <title>System Maintenance</title>
    <style>
        body { font-family: Arial; text-align: center; padding: 50px; }
        h1 { color: #e74c3c; }
    </style>
</head>
<body>
    <h1>System Under Maintenance</h1>
    <p>We are currently performing emergency maintenance.</p>
    <p>Please check back later.</p>
</body>
</html>
MAINTENANCE
                
                docker compose up -d
                echo "⚠️  Maintenance mode activated"
            fi
        else
            echo "Restoring from: $EMERGENCY_BACKUP"
            
            # Clear and restore
            rm -rf $APP_DIR/*
            cd $APP_DIR
            tar xzf $EMERGENCY_BACKUP
            
            # Start with safe mode
            docker compose up -d --scale web=1
            
            echo "✅ Emergency restore completed"
        fi
EMERGENCY_ROLLBACK
        ;;
        
    4)
        # View current deployment info
        echo -e "${YELLOW}Current Deployment Information${NC}"
        
        ssh -i "$SSH_KEY" root@$SERVER_IP << 'DEPLOYMENT_INFO'
        APP_DIR="/opt/legal-rag-mexico"
        
        echo "===================================="
        echo "Deployment Status"
        echo "===================================="
        
        # Deployment timestamp
        if [ -f "$APP_DIR/.deployment_info" ]; then
            cat $APP_DIR/.deployment_info
        else
            echo "Deployment Time: Unknown"
        fi
        
        # Git info if available
        if [ -d "$APP_DIR/.git" ]; then
            cd $APP_DIR
            echo "Git Branch: $(git branch --show-current 2>/dev/null || echo 'N/A')"
            echo "Last Commit: $(git log -1 --format='%h - %s' 2>/dev/null || echo 'N/A')"
        fi
        
        # Docker services
        echo ""
        echo "Docker Services:"
        cd $APP_DIR 2>/dev/null && docker compose ps || echo "No services running"
        
        # Disk usage
        echo ""
        echo "Disk Usage:"
        df -h $APP_DIR | tail -1
        
        # Recent logs
        echo ""
        echo "Recent Errors (last 10):"
        cd $APP_DIR 2>/dev/null && docker compose logs --tail=100 2>/dev/null | grep -i error | tail -10 || echo "No recent errors"
DEPLOYMENT_INFO
        ;;
        
    5)
        echo "Exiting rollback system"
        exit 0
        ;;
        
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# Post-rollback actions
echo ""
echo -e "${YELLOW}Post-Rollback Checklist:${NC}"
echo "1. Check application: http://$SERVER_IP"
echo "2. Review logs: ssh -i $SSH_KEY root@$SERVER_IP 'docker compose logs -f'"
echo "3. Run health check: ./health-check.sh"
echo "4. Monitor performance: ./monitor-legalrag.sh"
echo ""

# Create post-rollback report
ssh -i "$SSH_KEY" root@$SERVER_IP << 'POST_ROLLBACK'
REPORT_FILE="/mnt/data/logs/rollback_$(date +%Y%m%d_%H%M%S).log"

cat > $REPORT_FILE << REPORT
Rollback Report
===============
Date: $(date)
Action: $OPTION
Status: Completed

Services Status:
$(cd /opt/legal-rag-mexico && docker compose ps)

System Resources:
$(free -h)
$(df -h /mnt/data)

Recent Logs:
$(cd /opt/legal-rag-mexico && docker compose logs --tail=20)
REPORT

echo "Rollback report saved to: $REPORT_FILE"
POST_ROLLBACK

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Rollback process completed${NC}"
echo -e "${GREEN}================================================${NC}"