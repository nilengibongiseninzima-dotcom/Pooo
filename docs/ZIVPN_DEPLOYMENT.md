# ZiVPN Production Deployment

## Pre-Deployment Checklist

- [ ] Oracle account created and verified
- [ ] API credentials obtained
- [ ] SSH keys configured
- [ ] Terraform installed locally
- [ ] VPN protocol documented
- [ ] Encryption key generated
- [ ] Firewall rules reviewed
- [ ] Backup strategy planned

---

## Deployment Steps

### 1. Infrastructure Setup

```bash
# Initialize Terraform
cd terraform/oracle-free
terraform init

# Plan deployment
terraform plan -out=tfplan

# Apply configuration
terraform apply tfplan
```

### 2. Get Instance IP

```bash
TERRAFORM_OUTPUT=$(terraform output instance_public_ip)
echo "Server IP: $TERRAFORM_OUTPUT"
```

### 3. Connect to Instance

```bash
ssh -i ~/.ssh/your-key ubuntu@$TERRAFORM_OUTPUT
```

### 4. Verify ZiVPN Service

```bash
# Check service is running
sudo systemctl status zivpn

# Check ports are listening
sudo ss -ulnp | grep 1194

# Test HTTP dashboard
curl http://localhost:8080/health
```

---

## Configuration Management

### Update Encryption Key

```bash
# Generate new encryption key
openssl rand -base64 32

# Update config
sudo nano /opt/zivpn/config.json

# Restart service
sudo systemctl restart zivpn
```

### Update Ports

```bash
# Edit config
sudo nano /opt/zivpn/config.json

# Modify:
# "udp_port": 1194,
# "udp_port_failover": 1195,
# "udp_port_stealth": 443,

# Restart
sudo systemctl restart zivpn
```

---

## Monitoring Setup

### Dashboard Access

```bash
# From local machine
open http://<server-ip>:8080

# Or via SSH tunnel
ssh -L 8080:localhost:8080 ubuntu@<server-ip>
open http://localhost:8080
```

### Automated Alerting

```bash
#!/bin/bash
# Monitor ZiVPN health every 5 minutes

while true; do
    STATUS=$(curl -s http://<server-ip>:8080/health | jq -r '.status')
    
    if [ "$STATUS" != "ok" ]; then
        echo "⚠️ ZiVPN is not responding!"
        # Send alert (email, slack, etc)
    fi
    
    sleep 300
done
```

---

## Performance Tuning

### System Level

```bash
# Increase UDP buffer
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728
sudo sysctl -w net.ipv4.udp_mem="102400 873800 2097152"

# Persist changes
sudo bash -c 'echo "net.core.rmem_max=134217728" >> /etc/sysctl.conf'
sudo sysctl -p
```

### Application Level

```json
{
  "performance": {
    "worker_threads": 4,
    "packet_queue_size": 50000,
    "connection_pool_size": 10000
  },
  "network": {
    "buffer_size": 131072
  }
}
```

---

## Scaling

### Horizontal Scaling

Deploy multiple instances:

```bash
# Deploy second instance in different region
cp -r terraform/oracle-free terraform/oracle-free-2
cd terraform/oracle-free-2
# Update variables for different region
terraform apply
```

### Load Balancing

```bash
# Add load balancer configuration
# Point clients to load balancer IP
# Load balancer routes to multiple ZiVPN instances
```

---

## Backup & Recovery

### Backup Configuration

```bash
#!/bin/bash
BACKUP_DIR="/backup/zivpn"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup config
cp /opt/zivpn/config.json $BACKUP_DIR/config_$DATE.json

# Backup terraform state
cp terraform/oracle-free/terraform.tfstate* $BACKUP_DIR/

# Compress
tar -czf $BACKUP_DIR/backup_$DATE.tar.gz $BACKUP_DIR/*
echo "✅ Backup complete: $BACKUP_DIR/backup_$DATE.tar.gz"
```

### Recovery Procedure

```bash
# 1. Restore from backup
tar -xzf /backup/zivpn/backup_$DATE.tar.gz -C /

# 2. Verify config
cat /opt/zivpn/config.json

# 3. Restart service
sudo systemctl restart zivpn

# 4. Test
curl http://localhost:8080/health
```

---

## Maintenance

### Update System

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

### Update Node.js

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo systemctl restart zivpn
```

### Clean Logs

```bash
# Keep only last 7 days
sudo journalctl --vacuum=time=7d
```

---

## Security Hardening

### SSH Security

```bash
# Disable password auth
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Disable root login
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Restart SSH
sudo systemctl restart ssh
```

### Firewall Rules

```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow UDP ports
sudo ufw allow 1194/udp
sudo ufw allow 1195/udp
sudo ufw allow 443/udp

# Allow HTTP dashboard
sudo ufw allow 8080/tcp

# Enable firewall
sudo ufw enable
```

### Fail2Ban (DDoS Protection)

```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

---

## Testing

### Connectivity Test

```bash
# Test from client machine
nc -u <server-ip> 1194

# Should send/receive data
```

### Load Test

```bash
# Install stress test tool
sudo apt install iperf3

# Run server
iperf3 -s -u

# Run client
iperf3 -c <server-ip> -u
```

### Encryption Test

```bash
# Verify packets are encrypted
sudo tcpdump -i eth0 -n 'udp port 1194' -X
```

---

## Cost Optimization

Oracle Always Free Tier = **$0/month** ✅

No optimization needed - it's already free!

---

## Troubleshooting

### High CPU Usage

```bash
# Check what's using CPU
top

# Reduce worker threads
sudo nano /opt/zivpn/config.json
# Set "worker_threads": 2

# Restart
sudo systemctl restart zivpn
```

### High Memory Usage

```bash
# Check memory
free -h

# Reduce connection pool
sudo nano /opt/zivpn/config.json
# Set "connection_pool_size": 5000

# Restart
sudo systemctl restart zivpn
```

### Connection Timeouts

```bash
# Increase timeout
sudo nano /opt/zivpn/config.json
# Set "connection_timeout_ms": 600000

# Restart
sudo systemctl restart zivpn
```
