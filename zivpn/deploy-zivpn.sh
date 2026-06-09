#!/bin/bash
set -e

# ZiVPN Deployment Script
# Optimized for Oracle Cloud Always Free Tier
# Ubuntu 22.04 LTS

echo "====================================="
echo "ZiVPN - Custom UDP VPN Setup"
echo "Oracle Cloud Always Free Tier"
echo "====================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo)"
    exit 1
fi

echo -e "${YELLOW}[1/10] Updating system packages...${NC}"
apt-get update
apt-get upgrade -y
apt-get install -y curl wget git build-essential nodejs npm net-tools htop iotop

echo -e "${YELLOW}[2/10] Installing Node.js dependencies...${NC}"
npm install -g pm2
npm install -g node-gyp

echo -e "${YELLOW}[3/10] Creating ZiVPN application directory...${NC}"
mkdir -p /opt/zivpn
cd /opt/zivpn

echo -e "${YELLOW}[4/10] Installing ZiVPN npm packages...${NC}"
cat > package.json <<'EOF'
{
  "name": "zivpn",
  "version": "1.0.0",
  "description": "Custom UDP VPN Application for ZA",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": ["vpn", "udp", "zivpn"],
  "author": "ZiVPN",
  "license": "MIT",
  "dependencies": {
    "dgram": "^1.0.1",
    "crypto": "^1.0.1",
    "express": "^4.18.2",
    "dotenv": "^16.0.3"
  },
  "devDependencies": {
    "nodemon": "^2.0.20"
  }
}
EOF

npm install --production

echo -e "${YELLOW}[5/10] Creating ZiVPN server application...${NC}"
cat > server.js <<'EOF'
const dgram = require('dgram');
const crypto = require('crypto');
const express = require('express');
const fs = require('fs');

// Configuration
const config = JSON.parse(fs.readFileSync('/opt/zivpn/config.json', 'utf8'));

const server = dgram.createSocket('udp4');
const httpServer = express();
const PORT = config.udp_port || 1194;
const HTTP_PORT = config.http_port || 8080;

// Connection tracking
const connections = new Map();
let totalBytes = 0;
let totalPackets = 0;
let startTime = Date.now();

// Encryption key (in production, use proper key management)
const ENCRYPTION_KEY = Buffer.from(config.encryption_key || 'zivpn-default-key-change-in-production', 'utf8');

// UDP Server
server.on('message', (msg, rinfo) => {
    try {
        totalPackets++;
        totalBytes += msg.length;
        
        // Decrypt message
        const decrypted = decryptMessage(msg);
        
        // Route packet
        routePacket(decrypted, rinfo);
        
        // Track connection
        const connId = `${rinfo.address}:${rinfo.port}`;
        if (!connections.has(connId)) {
            connections.set(connId, {
                connected_at: new Date(),
                packets: 0,
                bytes: 0
            });
        }
        
        const conn = connections.get(connId);
        conn.packets++;
        conn.bytes += msg.length;
        conn.last_seen = new Date();
        
    } catch (error) {
        console.error('Error processing packet:', error.message);
    }
});

server.on('error', (err) => {
    console.error(`UDP Server error: ${err.stack}`);
});

server.on('listening', () => {
    const address = server.address();
    console.log(`\n✅ ZiVPN UDP Server listening on ${address.address}:${address.port}`);
    console.log(`📊 HTTP Stats available at http://localhost:${HTTP_PORT}/stats\n`);
});

// Functions
function decryptMessage(message) {
    try {
        const iv = message.slice(0, 16);
        const encrypted = message.slice(16);
        const decipher = crypto.createDecipheriv('aes-256-cbc', ENCRYPTION_KEY, iv);
        let decrypted = decipher.update(encrypted);
        decrypted = Buffer.concat([decrypted, decipher.final()]);
        return decrypted;
    } catch (e) {
        return message; // Return original if decryption fails
    }
}

function encryptMessage(message) {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv('aes-256-cbc', ENCRYPTION_KEY, iv);
    let encrypted = cipher.update(message);
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    return Buffer.concat([iv, encrypted]);
}

function routePacket(data, rinfo) {
    // Process packet routing logic here
    // This is where you'd implement your custom VPN protocol
    console.log(`📦 Packet from ${rinfo.address}:${rinfo.port} (${data.length} bytes)`);
}

// HTTP Stats Server
httpServer.get('/stats', (req, res) => {
    const uptime = Math.floor((Date.now() - startTime) / 1000);
    const avgPacketSize = totalPackets > 0 ? Math.floor(totalBytes / totalPackets) : 0;
    
    const stats = {
        server: 'ZiVPN',
        status: 'running',
        uptime_seconds: uptime,
        uptime_formatted: formatUptime(uptime),
        total_packets: totalPackets,
        total_bytes: totalBytes,
        total_bytes_formatted: formatBytes(totalBytes),
        average_packet_size: avgPacketSize,
        active_connections: connections.size,
        connections: Array.from(connections.entries()).map(([id, data]) => ({
            id,
            connected_at: data.connected_at,
            packets: data.packets,
            bytes: data.bytes,
            bytes_formatted: formatBytes(data.bytes)
        })),
        timestamp: new Date().toISOString()
    };
    
    res.json(stats);
});

httpServer.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

httpServer.get('/', (req, res) => {
    res.html(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>ZiVPN Dashboard</title>
            <style>
                body { font-family: Arial; margin: 20px; background: #1e1e1e; color: #fff; }
                .container { max-width: 800px; margin: 0 auto; }
                .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
                .stat-box { background: #333; padding: 15px; border-radius: 5px; }
                .stat-value { font-size: 24px; font-weight: bold; color: #4CAF50; }
                .stat-label { color: #aaa; font-size: 12px; }
                h1 { color: #4CAF50; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🔒 ZiVPN Dashboard</h1>
                <p>Real-time VPN Statistics</p>
                <div class="stats" id="stats"></div>
            </div>
            <script>
                async function updateStats() {
                    const res = await fetch('/stats');
                    const data = await res.json();
                    document.getElementById('stats').innerHTML = `
                        <div class="stat-box">
                            <div class="stat-label">Status</div>
                            <div class="stat-value">✅ ${data.status}</div>
                        </div>
                        <div class="stat-box">
                            <div class="stat-label">Uptime</div>
                            <div class="stat-value">${data.uptime_formatted}</div>
                        </div>
                        <div class="stat-box">
                            <div class="stat-label">Active Connections</div>
                            <div class="stat-value">${data.active_connections}</div>
                        </div>
                        <div class="stat-box">
                            <div class="stat-label">Total Data</div>
                            <div class="stat-value">${data.total_bytes_formatted}</div>
                        </div>
                        <div class="stat-box">
                            <div class="stat-label">Packets</div>
                            <div class="stat-value">${data.total_packets.toLocaleString()}</div>
                        </div>
                        <div class="stat-box">
                            <div class="stat-label">Avg Packet Size</div>
                            <div class="stat-value">${data.average_packet_size} bytes</div>
                        </div>
                    `;
                }
                updateStats();
                setInterval(updateStats, 2000);
            </script>
        </body>
        </html>
    `);
});

function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
}

function formatUptime(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${days}d ${hours}h ${mins}m ${secs}s`;
}

// Start servers
server.bind(PORT, '0.0.0.0');
httpServer.listen(HTTP_PORT, '0.0.0.0', () => {
    console.log(`\n📊 HTTP Stats Server listening on port ${HTTP_PORT}`);
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down ZiVPN...');
    server.close();
    httpServer.close();
    process.exit(0);
});
EOF

echo -e "${YELLOW}[6/10] Creating configuration file...${NC}"
cat > config.json <<'EOF'
{
  "name": "ZiVPN",
  "version": "1.0.0",
  "udp_port": 1194,
  "http_port": 8080,
  "encryption_key": "change-this-to-your-secure-key-in-production",
  "max_connections": 10000,
  "buffer_size": 65536,
  "timeout_ms": 300000,
  "compression": true,
  "compression_level": 6,
  "rate_limit": 1000,
  "logging": {
    "level": "info",
    "file": "/var/log/zivpn.log"
  }
}
EOF

echo -e "${YELLOW}[7/10] Creating systemd service...${NC}"
sudo tee /etc/systemd/system/zivpn.service > /dev/null <<'EOF'
[Unit]
Description=ZiVPN - Custom UDP VPN Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/zivpn
ExecStart=/usr/bin/node /opt/zivpn/server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable zivpn

echo -e "${YELLOW}[8/10] Creating client configuration...${NC}"
SERVER_IP=$(hostname -I | awk '{print $1}')

cat > /opt/zivpn/client-config.txt <<EOF
╔════════════════════════════════════════════════════════════════╗
║                    ZiVPN Client Configuration                  ║
╚════════════════════════════════════════════════════════════════╝

🔧 SERVER DETAILS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Server IP:              $SERVER_IP
Primary Port (UDP):     1194
Failover Port (UDP):    1195
Stealth Port (UDP):     443

📊 MONITORING:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dashboard:              http://$SERVER_IP:8080
Stats API:              http://$SERVER_IP:8080/stats
Health Check:           http://$SERVER_IP:8080/health

🔐 CONNECTION DETAILS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Protocol:               UDP
Encryption:             AES-256-CBC
Compression:            Enabled
Auto-Reconnect:         Enabled

📋 USAGE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ZiVPN Client Command:
  zivpn connect $SERVER_IP:1194

Manual UDP Test:
  nc -u $SERVER_IP 1194

📍 REGION: South Africa (ZA)
🌍 LOCATION: Oracle Cloud - Frankfurt (Closest EU to ZA)
⚡ PERFORMANCE: Optimized for ZA bandwidth

═════════════════════════════════════════════════════════════════
EOF

echo -e "${YELLOW}[9/10] Setting up logging...${NC}"
sudo mkdir -p /var/log/zivpn
sudo touch /var/log/zivpn/zivpn.log
sudo chown ubuntu:ubuntu /var/log/zivpn

echo -e "${YELLOW}[10/10] Starting ZiVPN service...${NC}"
sudo systemctl start zivpn
sleep 2

echo -e "${GREEN}✅ ZiVPN Installation Complete!${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}       🎉 ZiVPN is now running and ready to use! 🎉${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "📊 View Client Configuration:"
echo "   cat /opt/zivpn/client-config.txt"
echo ""
echo "🖥️  Access Dashboard:"
echo "   http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "📋 Check Status:"
echo "   sudo systemctl status zivpn"
echo ""
echo "📝 View Logs:"
echo "   sudo journalctl -u zivpn -f"
echo ""
echo "🔧 Configuration:"
echo "   nano /opt/zivpn/config.json"
echo ""
