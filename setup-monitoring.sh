#!/bin/bash

# =====================================================
# Monitoring Dashboard Setup for LegalTracking RAG
# Grafana + Prometheus + Node Exporter
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
GRAFANA_PORT="3000"
PROMETHEUS_PORT="9090"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}📊 Monitoring Dashboard Setup${NC}"
echo -e "${BLUE}================================================${NC}"

echo -e "${YELLOW}This will install:${NC}"
echo "• Prometheus (metrics collection)"
echo "• Grafana (visualization dashboard)"
echo "• Node Exporter (system metrics)"
echo "• Custom dashboards for your application"
echo ""
read -p "Continue with installation? (y/n): " CONTINUE

if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
    exit 0
fi

# Setup monitoring on server
ssh -i "$SSH_KEY" root@$SERVER_IP << 'MONITORING_SETUP'
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}Installing monitoring stack...${NC}"

# Create monitoring directory
MONITORING_DIR="/opt/monitoring"
mkdir -p $MONITORING_DIR
cd $MONITORING_DIR

# Create docker-compose for monitoring
cat > docker-compose.yml << 'MONITORING_COMPOSE'
version: '3.8'

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/data/prometheus
  grafana_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/data/grafana

services:
  # Prometheus - Metrics collection
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    networks:
      - monitoring

  # Grafana - Visualization
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=LegalTracking2024!
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
      - GF_SERVER_ROOT_URL=http://5.161.120.86:3000
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    ports:
      - "3000:3000"
    networks:
      - monitoring

  # Node Exporter - System metrics
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - monitoring

  # cAdvisor - Container metrics
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    devices:
      - /dev/kmsg:/dev/kmsg
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
      - /cgroup:/cgroup:ro
    ports:
      - "8080:8080"
    networks:
      - monitoring

  # Loki - Log aggregation (optional)
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yaml:/etc/loki/local-config.yaml
      - /mnt/data/loki:/loki
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - monitoring

  # Promtail - Log shipping
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    volumes:
      - /var/log:/var/log:ro
      - /opt/legal-rag-mexico/logs:/app/logs:ro
      - ./promtail-config.yaml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    networks:
      - monitoring
MONITORING_COMPOSE

# Create data directories
mkdir -p /mnt/data/{prometheus,grafana,loki}
chmod 777 /mnt/data/grafana  # Grafana needs write permissions

# Create Prometheus configuration
cat > prometheus.yml << 'PROMETHEUS_CONFIG'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files:
  - "alerts.yml"

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter - System metrics
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  # Docker containers
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  # Application metrics (if exposed)
  - job_name: 'legalrag-app'
    static_configs:
      - targets: ['host.docker.internal:80']
    metrics_path: '/metrics'
PROMETHEUS_CONFIG

# Create alerts configuration
cat > alerts.yml << 'ALERTS_CONFIG'
groups:
  - name: system
    interval: 30s
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% (current value: {{ $value }}%)"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85% (current value: {{ $value }}%)"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/mnt/data"} / node_filesystem_size_bytes{mountpoint="/mnt/data"}) * 100 < 20
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space on data volume"
          description: "Less than 20% disk space remaining on /mnt/data"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.job }} has been down for more than 1 minute"
ALERTS_CONFIG

# Create Loki configuration
cat > loki-config.yaml << 'LOKI_CONFIG'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
LOKI_CONFIG

# Create Promtail configuration
cat > promtail-config.yaml << 'PROMTAIL_CONFIG'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

  - job_name: legalrag
    static_configs:
      - targets:
          - localhost
        labels:
          job: legalrag
          __path__: /app/logs/*.log
PROMTAIL_CONFIG

# Create Grafana provisioning directories
mkdir -p grafana/provisioning/{datasources,dashboards}

# Configure Grafana datasources
cat > grafana/provisioning/datasources/prometheus.yml << 'GRAFANA_DATASOURCES'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
GRAFANA_DATASOURCES

# Create dashboard provisioning
cat > grafana/provisioning/dashboards/dashboards.yml << 'DASHBOARD_PROVISION'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/provisioning/dashboards
DASHBOARD_PROVISION

# Create custom dashboard for LegalTracking
cat > grafana/provisioning/dashboards/legaltracking.json << 'CUSTOM_DASHBOARD'
{
  "dashboard": {
    "title": "LegalTracking RAG System",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU %"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "Memory %"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "title": "Disk Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "100 - (node_filesystem_avail_bytes{mountpoint=\"/mnt/data\"} / node_filesystem_size_bytes{mountpoint=\"/mnt/data\"}) * 100",
            "legendFormat": "Used %"
          }
        ],
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 8}
      },
      {
        "title": "Container Count",
        "type": "stat",
        "targets": [
          {
            "expr": "count(container_last_seen)",
            "legendFormat": "Containers"
          }
        ],
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 8}
      },
      {
        "title": "Network I/O",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_network_receive_bytes_total[5m])",
            "legendFormat": "RX {{device}}"
          },
          {
            "expr": "rate(node_network_transmit_bytes_total[5m])",
            "legendFormat": "TX {{device}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ],
    "refresh": "10s",
    "time": {
      "from": "now-1h",
      "to": "now"
    }
  },
  "overwrite": true
}
CUSTOM_DASHBOARD

# Start monitoring stack
echo -e "${YELLOW}Starting monitoring services...${NC}"
docker compose up -d

# Wait for services to start
sleep 15

# Check services
echo -e "${YELLOW}Checking service health...${NC}"
docker compose ps

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw allow 3000/tcp  # Grafana
ufw allow 9090/tcp  # Prometheus (optional, for direct access)
ufw reload

echo -e "${GREEN}✓ Monitoring stack installed${NC}"

# Create monitoring helper script
cat > /usr/local/bin/monitor-status << 'MONITOR_SCRIPT'
#!/bin/bash
echo "==================================="
echo "Monitoring Stack Status"
echo "==================================="
cd /opt/monitoring
docker compose ps
echo ""
echo "Access URLs:"
echo "  Grafana: http://5.161.120.86:3000"
echo "  Prometheus: http://5.161.120.86:9090"
echo ""
echo "Grafana Credentials:"
echo "  Username: admin"
echo "  Password: LegalTracking2024!"
echo ""
echo "Disk Usage:"
df -h /mnt/data/prometheus /mnt/data/grafana
MONITOR_SCRIPT

chmod +x /usr/local/bin/monitor-status

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ MONITORING SETUP COMPLETE!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Access your dashboards:"
echo "  Grafana: http://5.161.120.86:3000"
echo "    Username: admin"
echo "    Password: LegalTracking2024!"
echo ""
echo "  Prometheus: http://5.161.120.86:9090"
echo ""
echo "Run 'monitor-status' to check monitoring health"
echo -e "${GREEN}================================================${NC}"

MONITORING_SETUP

# Create local monitoring access script
cat > monitor-dashboard.sh << 'LOCAL_MONITOR'
#!/bin/bash

SERVER_IP="5.161.120.86"
GRAFANA_URL="http://$SERVER_IP:3000"
PROMETHEUS_URL="http://$SERVER_IP:9090"

echo "================================================"
echo "📊 LegalTracking Monitoring Dashboard"
echo "================================================"
echo ""
echo "Opening monitoring dashboards..."
echo ""
echo "Grafana Dashboard: $GRAFANA_URL"
echo "  Username: admin"
echo "  Password: LegalTracking2024!"
echo ""
echo "Prometheus: $PROMETHEUS_URL"
echo ""

# Try to open in browser
if command -v xdg-open &> /dev/null; then
    xdg-open "$GRAFANA_URL" 2>/dev/null
elif command -v open &> /dev/null; then
    open "$GRAFANA_URL" 2>/dev/null
else
    echo "Please open $GRAFANA_URL in your browser"
fi

echo "================================================"
LOCAL_MONITOR

chmod +x monitor-dashboard.sh

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}✅ Monitoring Dashboard Setup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${BLUE}Access your monitoring:${NC}"
echo "  • Grafana: http://$SERVER_IP:3000"
echo "    Username: admin"
echo "    Password: LegalTracking2024!"
echo ""
echo -e "${BLUE}Local commands:${NC}"
echo "  • Open dashboard: ./monitor-dashboard.sh"
echo "  • Check health: ./health-check.sh"
echo "  • View status: ssh -i $SSH_KEY root@$SERVER_IP 'monitor-status'"
echo ""
echo -e "${YELLOW}First-time setup:${NC}"
echo "1. Open Grafana in your browser"
echo "2. Login with credentials above"
echo "3. Navigate to Dashboards > LegalTracking RAG System"
echo "4. Customize as needed"
echo ""
echo -e "${GREEN}================================================${NC}"