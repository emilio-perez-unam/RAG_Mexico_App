# 🚀 LegalTracking RAG System - Hetzner Quick Start Guide

## Your Server Details
- **Name**: LegalTracking-Rag-System
- **Type**: ccx13 (2 vCPU, 8GB RAM, 80GB disk)
- **Volume**: 250GB attached storage
- **Location**: Ashburn, VA (us-east)
- **Monthly Cost**: $14.49

## 📋 Step-by-Step Deployment

### Step 1: Get Your Server IP
1. Go to your [Hetzner Cloud Console](https://console.hetzner.cloud)
2. Click on your server "LegalTracking-Rag-System"
3. Copy the IPv4 address
4. Save it here: `YOUR_IP=` _______________

### Step 2: Initial Server Access
```bash
# SSH into your server (replace with your IP)
ssh root@YOUR_IP

# If prompted about fingerprint, type 'yes'
```

### Step 3: Quick Server Setup
Once connected to your server, run these commands:

```bash
# Download and run the automated setup
curl -O https://raw.githubusercontent.com/yourusername/legal-rag-mexico/main/setup-legaltracking-server.sh
chmod +x setup-legaltracking-server.sh
./setup-legaltracking-server.sh
```

**OR** manually run this all-in-one command:

```bash
# Complete server setup in one command
bash <(curl -s https://raw.githubusercontent.com/yourusername/legal-rag-mexico/main/setup-legaltracking-server.sh)
```

### Step 4: Configure Your API Keys

After setup completes, configure your API keys:

```bash
# Edit the environment file
nano /opt/legal-rag-mexico/.env
```

Update these values:
```env
DEEPSEEK_API_KEY=your_actual_deepseek_key
SUPABASE_URL=your_actual_supabase_url
SUPABASE_ANON_KEY=your_actual_supabase_anon_key
```

Save with `Ctrl+X`, then `Y`, then `Enter`.

### Step 5: Start the Application

```bash
cd /opt/legal-rag-mexico
docker compose up -d
```

### Step 6: Verify Deployment

```bash
# Check if services are running
docker compose ps

# View logs
docker compose logs -f legal-rag-web

# Test the application
curl http://localhost/health
```

## 🌐 Access Your Application

- **Direct IP**: http://YOUR_IP
- **With Domain**: https://your-domain.com (after DNS setup)

## 🔧 Common Commands

### Application Management
```bash
# Restart application
docker compose restart

# Stop application
docker compose down

# View logs
docker compose logs -f

# Update application
git pull
docker compose build
docker compose up -d
```

### Server Monitoring
```bash
# Check disk usage (especially the 250GB volume)
df -h /mnt/data

# Check memory usage
free -h

# Check Docker stats
docker stats

# View system resources
htop
```

### Backup Management
```bash
# Manual backup
/opt/backup-legaltracking.sh

# Check backup status
ls -lah /mnt/data/backups/

# Restore from backup
cd /opt/legal-rag-mexico
docker compose down
# Restore your backup files
docker compose up -d
```

## 📊 Volume Usage

Your 250GB volume is mounted at `/mnt/data` and organized as:

```
/mnt/data/
├── docker/       # Docker images and containers
├── postgres/     # Database files
├── redis/        # Cache data
├── milvus/       # Vector database
├── app/          # Application data
├── uploads/      # User uploads
├── backups/      # Automated backups
└── logs/         # Application logs
```

## 🔒 Security Checklist

- [x] UFW firewall enabled (ports 22, 80, 443 only)
- [x] Fail2ban configured for SSH protection
- [x] 4GB swap configured for stability
- [ ] SSL certificate (run after domain setup)
- [ ] Regular security updates (`apt update && apt upgrade`)

## 🆘 Troubleshooting

### Application Won't Start
```bash
# Check logs for errors
docker compose logs --tail=50

# Restart Docker
systemctl restart docker
docker compose up -d
```

### Out of Disk Space
```bash
# Check what's using space
du -h --max-depth=1 /mnt/data

# Clean Docker
docker system prune -af

# Clean old logs
find /mnt/data/logs -name "*.log" -mtime +30 -delete
```

### High Memory Usage
```bash
# Check memory consumers
ps aux --sort=-%mem | head

# Restart services
docker compose restart

# Clear cache if needed
sync && echo 3 > /proc/sys/vm/drop_caches
```

## 📈 Performance Optimization

Your ccx13 server with 2 vCPU and 8GB RAM is optimized for:
- **Concurrent Users**: ~100-200
- **Requests/sec**: ~500-1000
- **Storage**: 250GB for documents and data

To scale further:
1. Enable Redis caching: `docker compose --profile cache up -d`
2. Use CDN for static assets
3. Upgrade to ccx23 (4 vCPU, 16GB RAM) if needed

## 💰 Cost Breakdown

- **Server (ccx13)**: $14.49/month
- **250GB Volume**: Included
- **Traffic**: 1TB included (more than enough)
- **Backups**: Free (automated daily)
- **Total**: **$14.49/month**

## 📞 Support Contacts

- **Hetzner Support**: https://console.hetzner.cloud/support
- **Server Status**: Check in Hetzner Console
- **Application Issues**: Check `/mnt/data/logs/`

## 🎯 Next Steps

1. ✅ Server is running
2. ✅ Application deployed
3. ⏳ Configure your domain (optional)
4. ⏳ Setup SSL certificate
5. ⏳ Configure monitoring alerts
6. ⏳ Test with production data

---

**Quick Check**: Your application should now be accessible at:
```
http://YOUR_SERVER_IP
```

Replace `YOUR_SERVER_IP` with the actual IP from Hetzner Console!