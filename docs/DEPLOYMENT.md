# Deployment Guide

## Pre-Deployment Checklist

- [ ] VPS provisioned and accessible via SSH
- [ ] SSH key authentication configured
- [ ] Domain registered and DNS configured
- [ ] Application code in git repository
- [ ] Environment variables documented
- [ ] Database migrations tested

---

## Deploy Application

### Method 1: Automated Script
```bash
bash scripts/deploy.sh <server-ip> <app-name>
```

### Method 2: Manual Deployment

```bash
# 1. SSH into server
ssh appuser@<server-ip>

# 2. Clone application
cd ~/app
git clone <your-repo>.git .

# 3. Configure environment
cp .env.example .env
# Edit .env with actual values
nano .env

# 4. Build and run
docker-compose build
docker-compose up -d

# 5. Run migrations
docker-compose exec app npm run migrate

# 6. Health check
curl http://localhost:3000/health
```

---

## SSL/TLS Certificate Setup

### Automatic (Let's Encrypt)
```bash
ssh appuser@<server-ip>

sudo certbot certonly --standalone -d yourdomain.com

# Update nginx config with certificate paths
sudo nano /etc/nginx/conf.d/default.conf
# Add:
# ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
# ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

sudo systemctl reload nginx
```

### Auto-Renewal
```bash
# Already configured by cloud-init
# Check status:
sudo systemctl status certbot.timer
```

---

## Rollback Procedure

```bash
# 1. SSH to server
ssh appuser@<server-ip>

# 2. Stop current container
cd ~/app
docker-compose down

# 3. Revert code
git checkout <previous-commit>

# 4. Rebuild and restart
docker-compose up -d

# 5. Verify
curl http://localhost:3000/health
```

---

## Zero-Downtime Deployment

```bash
# 1. Pull new code
git pull origin main

# 2. Rebuild containers
docker-compose build

# 3. Start new containers (old still running)
docker-compose up -d

# 4. Wait for health checks to pass
sleep 10

# 5. Stop old containers
docker-compose down
```

---

## Database Migrations

```bash
# Run migrations
docker-compose exec app npm run migrate

# Check status
docker-compose exec app npm run migrate:status

# Rollback if needed
docker-compose exec app npm run migrate:rollback
```

---

## Monitoring Deployment

```bash
# View logs
docker-compose logs -f app

# Check health
curl -v http://localhost:3000/health

# Monitor resources
top
df -h
```
