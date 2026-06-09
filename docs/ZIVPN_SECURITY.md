# ZiVPN Security Guide

## Encryption

### Algorithm: AES-256-CBC

- **Strength**: Military-grade (256-bit keys)
- **Mode**: Cipher Block Chaining (CBC)
- **Key Size**: 256 bits (32 bytes)
- **IV**: Random 128-bit per packet

### Key Management

```bash
# Generate secure encryption key
openssl rand -base64 32

# Update in config
sudo nano /opt/zivpn/config.json
# Set: "encryption_key": "your-generated-key"

# Rotate key every 24 hours
# Set: "key_rotation_hours": 24
```

### Key Security

⚠️ **NEVER**:
- Share encryption key
- Commit key to git
- Log encryption key
- Use default key in production

✅ **DO**:
- Use unique, strong key
- Rotate regularly
- Store securely (env variables)
- Use secret management system

---

## Access Control

### SSH Access Only

```bash
# Disable password authentication
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
# Set: PubkeyAuthentication yes

# Disable root login
# Set: PermitRootLogin no

# Restart SSH
sudo systemctl restart ssh
```

### SSH Key Management

```bash
# Generate strong SSH key
ssh-keygen -t ed25519 -C "zivpn-key"

# Copy public key to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@<server-ip>

# Restrict key permissions
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

---

## Network Security

### Firewall Rules

```bash
# Enable UFW
sudo ufw enable

# Default deny all
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp

# Allow VPN ports
sudo ufw allow 1194/udp
sudo ufw allow 1195/udp
sudo ufw allow 443/udp

# Allow dashboard (local only)
sudo ufw allow from 127.0.0.1 to 127.0.0.1 port 8080

# View rules
sudo ufw status verbose
```

### DDoS Protection

```bash
# Enable in config
{
  "security": {
    "ddos_protection": true,
    "ddos_threshold": 10000,
    "rate_limit_packets_per_second": 1000
  }
}
```

### Fail2Ban (Brute Force Protection)

```bash
# Install
sudo apt install fail2ban

# Configure SSH jail
sudo nano /etc/fail2ban/jail.local

# Add:
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

# Start
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

---

## Application Security

### Input Validation

```javascript
// Validate packet size
if (msg.length > config.max_packet_size) {
    console.warn('Packet too large, dropping');
    return;
}

// Validate connection limit
if (connections.size >= config.max_connections) {
    console.warn('Max connections reached');
    return;
}
```

### Rate Limiting

```json
{
  "security": {
    "rate_limit_packets_per_second": 1000,
    "rate_limit_enabled": true
  }
}
```

### Connection Timeout

```json
{
  "network": {
    "connection_timeout_ms": 300000,
    "packet_timeout_ms": 60000
  }
}
```

---

## Data Protection

### Packet Encryption

All packets are encrypted before transmission:

```
[Random IV - 16 bytes]
+
[Encrypted Data - variable]
=
Complete Encrypted Packet
```

### No Logging of Sensitive Data

```bash
# Verify logs don't contain:
# - Encryption keys
# - Private IPs (internal only)
# - User data (application-level)
# - Connection keys

# Check logs
sudo journalctl -u zivpn | head -20
```

---

## Compliance

### Data Privacy

✅ **Encrypted in Transit**: AES-256  
✅ **Encryption at Rest**: Yes (config backup)  
✅ **Audit Logging**: Enabled  
✅ **User Authentication**: SSH keys  
✅ **Access Control**: Firewall + UFW  

### GDPR Compliance

- No personal data stored
- Minimal logging
- Secure deletion of old logs
- Data ownership with user

### Security Standards

- **NIST Recommended**: AES-256 ✅
- **Industry Standard**: TLS 1.3 ready ✅
- **Open Source**: Transparent security ✅

---

## Incident Response

### Suspicious Activity Detection

```bash
# Monitor connections
watch -n 5 'curl -s http://localhost:8080/stats | jq ".active_connections"'

# Check for unusual packet rates
journalctl -u zivpn | grep "packets" | tail -20

# View current connections
curl http://localhost:8080/stats | jq '.connections[]'
```

### Emergency Response

```bash
# Stop all connections
sudo systemctl stop zivpn

# View recent logs
sudo journalctl -u zivpn --since "1 hour ago"

# Restore from backup
sudo systemctl restore-backup

# Change encryption key
# Update config.json

# Restart service
sudo systemctl start zivpn
```

### Post-Incident

1. Analyze logs
2. Identify attack vector
3. Update security rules
4. Change credentials
5. Notify users if needed

---

## Security Checklist

- [ ] Encryption key changed from default
- [ ] SSH keys configured (no passwords)
- [ ] Firewall rules applied
- [ ] Fail2Ban enabled
- [ ] UFW enabled
- [ ] Updates applied (`apt upgrade`)
- [ ] Logs monitored
- [ ] Backup strategy in place
- [ ] DDoS protection enabled
- [ ] Rate limiting configured
- [ ] Connection timeouts set
- [ ] Regular security audits scheduled

---

## Security Resources

- **NIST Cryptography**: https://csrc.nist.gov/
- **OWASP Security**: https://owasp.org/
- **Ubuntu Security**: https://ubuntu.com/security
- **Oracle Security**: https://www.oracle.com/security/

---

## Support

Security Issues:
- DO NOT post in public issues
- Email: security@zivpn.local
- Include: Description, steps to reproduce, impact
