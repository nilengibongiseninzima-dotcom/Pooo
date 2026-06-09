# ZA Server VPS Setup Guide

## Overview

This guide covers the complete setup of a production-ready VPS with:
- **8 CPU cores**
- **6GB RAM**
- **1TB Storage**
- **Ubuntu 22.04 LTS**
- **Docker & Docker Compose**
- **Nginx + SSL**
- **PostgreSQL + Redis**
- **Monitoring & Backups**

---

## Prerequisites

1. **For DigitalOcean:**
   - DigitalOcean account with API token
   - Terraform installed locally
   - SSH key pair configured

2. **For Oracle Cloud:**
   - Oracle Cloud account
   - API credentials (Tenancy OCID, User OCID, Fingerprint)
   - Private key file
   - Terraform installed locally

---

## Quick Start - DigitalOcean

### Step 1: Prepare
```bash
cd terraform
cp digitalocean.tf .
```

### Step 2: Deploy
```bash
bash ../scripts/digitalocean-setup.sh your-digitalocean-token
```

### Step 3: Connect to VPS
```bash
ssh root@<droplet-ip>
```

---

## Quick Start - Oracle Cloud

### Step 1: Prepare Oracle Credentials
Gather your credentials from Oracle Cloud Console:
- Tenancy OCID
- User OCID
- API Key Fingerprint
- Path to private key file

### Step 2: Deploy
```bash
bash scripts/oracle-setup.sh
```

### Step 3: Connect to VPS
```bash
ssh ubuntu@<instance-public-ip>
```

---

## Post-Deployment Configuration

### 1. SSH Key Setup (First Boot)
```bash
ssh-keygen -t ed25519 -f ~/.ssh/za-server -C "za-server"
ssh-copy-id -i ~/.ssh/za-server.pub appuser@<server-ip>
```

### 2. Domain Setup
```bash
# Update Nginx config with your domain
sudo nano /etc/nginx/sites-available/default
# Replace _ with your domain name

# Obtain SSL certificate
sudo certbot certonly --nginx -d yourdomain.com

# Update nginx config with certificate paths
sudo systemctl reload nginx
```

### 3. Verify Services
```bash
ssh appuser@<server-ip>

# Check all services running
sudo systemctl status docker
sudo systemctl status nginx
sudo systemctl status postgresql
sudo systemctl status redis-server

# Check disk space
df -h

# Mount storage if not automatic
sudo mount /dev/sda /mnt/storage
```

### 4. Deploy Your Application
```bash
bash scripts/deploy.sh <server-ip> <app-name>
```

### 5. Setup Monitoring
```bash
bash scripts/monitoring-setup.sh
```

Access monitoring:
- Prometheus: `http://<server-ip>:9090`
- Grafana: `http://<server-ip>:3000` (admin/admin)

---

## Common Tasks

### Create Database
```bash
ssh appuser@<server-ip>

# Connect to PostgreSQL
sudo -u postgres psql

# Create database
CREATE DATABASE app_db;
CREATE USER app_user WITH PASSWORD 'strong-password';
ALTER ROLE app_user SET client_encoding TO 'utf8';
ALTER ROLE app_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE app_user SET default_transaction_deferrable TO on;
GRANT ALL PRIVILEGES ON DATABASE app_db TO app_user;
```

### Backup Database
```bash
bash scripts/backup.sh <server-ip> ./backups
```

### View Logs
```bash
ssh appuser@<server-ip>

# Application logs
docker-compose logs -f app

# Nginx logs
sudo tail -f /var/log/nginx/access.log

# System logs
sudo journalctl -u docker -f
```

### Scale Resources (if needed)
```bash
# For DigitalOcean: Use console to resize droplet
# For Oracle: Modify shape_config in oracle.tf
```

---

## Security Checklist

- [ ] SSH key-only authentication enabled
- [ ] Firewall rules configured (22, 80, 443)
- [ ] SSL certificate installed
- [ ] Fail2ban enabled
- [ ] Regular backups configured
- [ ] Monitoring alerts setup
- [ ] Updates scheduled (unattended-upgrades)
- [ ] Root login disabled
- [ ] Password authentication disabled

---

## Troubleshooting

### VPS Not Responding
```bash
# Check service status
sudo systemctl status docker
sudo systemctl status nginx

# Restart services
sudo systemctl restart docker
sudo systemctl restart nginx
```

### Storage Not Mounted
```bash
# List available disks
lsblk

# Mount manually
sudo mkdir -p /mnt/storage
sudo mkfs.ext4 /dev/sda1
sudo mount /dev/sda1 /mnt/storage

# Add to fstab for persistence
echo '/dev/sda1 /mnt/storage ext4 defaults 0 0' | sudo tee -a /etc/fstab
```

### Database Connection Failed
```bash
# Check PostgreSQL
sudo systemctl status postgresql
sudo -u postgres psql -c "SELECT version();"

# Check Redis
redis-cli ping
```

### SSL Certificate Issues
```bash
# Renew certificate
sudo certbot renew

# Check certificate expiry
sudo certbot certificates
```

---

## Performance Tuning

### PostgreSQL
```sql
-- Update postgresql.conf for 6GB RAM
shared_buffers = 1536MB
effective_cache_size = 4608MB
maintenance_work_mem = 384MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 393kB
min_wal_size = 1GB
max_wal_size = 4GB
```

### Redis
```bash
# redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru
```

### Nginx
```nginx
# Increase worker connections
worker_connections 2048;

# Enable caching
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=cache:10m;
```

---

## Support & Issues

- **DigitalOcean Support**: https://www.digitalocean.com/support
- **Oracle Cloud Support**: https://www.oracle.com/cloud/support
- **Ubuntu Support**: https://ubuntu.com/support
- **Docker Docs**: https://docs.docker.com

---

## License

MIT License - Feel free to use and modify as needed.
