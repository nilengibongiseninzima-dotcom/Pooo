# ZiVPN Setup Guide

## Prerequisites

✅ Oracle Cloud Always Free Account (No payment needed)  
✅ SSH Key Pair  
✅ Terraform installed locally  
✅ Oracle CLI credentials  

---

## Step 1: Create Oracle Cloud Free Account

1. Visit: https://www.oracle.com/cloud/free/
2. Click "Start for free"
3. Sign up with email (no payment needed upfront)
4. Verify email
5. Get $300 free credits + always-free resources

---

## Step 2: Setup Oracle Cloud Credentials

### Get API Credentials

1. Log in to Oracle Cloud Console
2. Click your profile (top-right)
3. Click "User Settings"
4. Scroll to "API Keys" section
5. Click "Add API Key"
6. Click "Generate API Key Pair"
7. **SAVE the private key** (you only get one chance!)
8. **Copy the Fingerprint**

### Get OCIDs

**Tenancy OCID:**
1. Click profile → "Tenancy: [your-tenancy]"
2. Copy the "OCID" value

**User OCID:**
1. Go to Profile → User Settings
2. Copy the "OCID" value

---

## Step 3: Deploy ZiVPN

```bash
# Navigate to terraform directory
cd terraform/oracle-free

# Initialize Terraform
terraform init

# Preview infrastructure
terraform plan

# Deploy!
terraform apply
```

Terraform will prompt you for:
- Tenancy OCID
- User OCID
- Fingerprint
- Private key path
- SSH public key path

---

## Step 4: Get Your Server IP

```bash
# After deployment completes, get the IP:
terraform output instance_public_ip

# SSH into your server
ssh ubuntu@<instance-public-ip>
```

---

## Step 5: Verify ZiVPN is Running

```bash
# Check service status
sudo systemctl status zivpn

# View logs
sudo journalctl -u zivpn -f

# Access dashboard
curl http://localhost:8080
```

---

## Configuration

Edit configuration at:
```bash
sudo nano /opt/zivpn/config.json
```

Key settings:
- `udp_port`: Primary port (1194)
- `encryption_key`: Change to your own secure key
- `max_connections`: Maximum concurrent connections
- `compression_level`: 1-9 (higher = more CPU, more compression)

---

## Client Configuration

Get your client config:
```bash
cat /opt/zivpn/client-config.txt
```

This shows:
- Server IP
- UDP ports
- Dashboard URL
- Connection details

---

## Monitoring

### Dashboard
```
http://<your-server-ip>:8080
```

### Stats API
```bash
curl http://<your-server-ip>:8080/stats | jq
```

### Real-time Logs
```bash
sudo journalctl -u zivpn -f
```

---

## Troubleshooting

### Service won't start
```bash
# Check for errors
sudo systemctl status zivpn
journalctl -u zivpn --no-pager | tail -20

# Restart service
sudo systemctl restart zivpn
```

### Can't connect to server
```bash
# Check firewall rules
sudo ufw status

# Check if ports are open
sudo ss -ulnp | grep 1194

# Test UDP connectivity
nc -u <server-ip> 1194
```

### Port already in use
```bash
# Find what's using the port
sudo lsof -i :1194

# Kill if needed
sudo kill -9 <PID>

# Change port in config.json
```

---

## Performance Tuning

### For High Traffic
```json
{
  "performance": {
    "worker_threads": 4,
    "packet_queue_size": 20000,
    "connection_pool_size": 10000
  }
}
```

### For Low Bandwidth
```json
{
  "compression": {
    "enabled": true,
    "level": 9
  }
}
```

---

## Security

✅ **Change encryption key** in config.json  
✅ **Use SSH keys only** (no passwords)  
✅ **Enable firewall** (UFW)  
✅ **Monitor connections** via dashboard  
✅ **Keep Ubuntu updated** (`sudo apt update && sudo apt upgrade`)  

---

## Backup

### Backup Configuration
```bash
sudo cp -r /opt/zivpn /backup/zivpn-$(date +%Y%m%d)
```

### Backup Oracle Terraform State
```bash
cp terraform/oracle-free/terraform.tfstate* ~/backup/
```

---

## Cost Breakdown (FREE Tier)

| Resource | Tier | Cost |
|----------|------|------|
| VM Instance (2 vCPU, 12GB) | Always Free | $0 |
| Bandwidth | Always Free | $0 |
| Storage (200GB) | Always Free | $0 |
| **TOTAL** | | **$0/month** |

---

## Support

- Oracle Support: https://www.oracle.com/cloud/support
- Ubuntu Support: https://ubuntu.com/support
- GitHub Issues: Include logs and config (without keys!)
