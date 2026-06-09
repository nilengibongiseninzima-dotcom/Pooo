#!/bin/bash
set -e

# VPS Initial Setup Script for Ubuntu 22.04 LTS
# This script runs on first boot via cloud-init

echo "Starting VPS initialization..."

# Update system packages
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y curl wget git build-essential htop net-tools vim nano

# Configure timezone to ZA
sudo timedatectl set-timezone Africa/Johannesburg

# Create application user
sudo useradd -m -s /bin/bash -G sudo appuser || true

# Mount additional storage if exists
echo "Checking for additional storage..."
if [ -b /dev/sda ] || [ -b /dev/vdb ]; then
    DEVICE=$(lsblk -nd -o NAME | grep -E 'sda|vdb' | tail -1)
    if [ ! -z "$DEVICE" ]; then
        sudo mkdir -p /mnt/storage
        sudo mkfs.ext4 -F /dev/$DEVICE || true
        sudo mount /dev/$DEVICE /mnt/storage
        echo "/dev/$DEVICE /mnt/storage ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
        sudo chown appuser:appuser /mnt/storage
    fi
fi

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker appuser
rm get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Node.js (LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Nginx
sudo apt-get install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Install SSL certificate with Certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Install PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Install Redis
sudo apt-get install -y redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Configure Firewall (UFW)
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable -y

# Create log directory
sudo mkdir -p /var/log/za-server
sudo chown appuser:appuser /var/log/za-server

# Setup log rotation
echo "/var/log/za-server/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 appuser appuser
    sharedscripts
}" | sudo tee /etc/logrotate.d/za-server

# Install Monitoring Tools
sudo apt-get install -y prometheus-node-exporter
sudo systemctl enable prometheus-node-exporter
sudo systemctl start prometheus-node-exporter

# Install fail2ban for security
sudo apt-get install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Enable automatic security updates
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# SSH hardening
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Create deployment directory
sudo mkdir -p /home/appuser/app
sudo chown appuser:appuser /home/appuser/app

# Swap creation (if needed)
SWAP_SIZE=2G
if [ ! -f /swapfile ]; then
    sudo dd if=/dev/zero of=/swapfile bs=1024 count=$((2 * 1024 * 1024))
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
fi

# Set up basic health check endpoint
sudo mkdir -p /var/www/health
echo '{"status": "healthy"}' | sudo tee /var/www/health/index.html

# Install PM2 for Node.js process management
sudo npm install -g pm2

# Create systemd service for PM2
sudo pm2 startup systemd -u appuser --hp /home/appuser

echo "VPS initialization complete!"
echo "Server is ready for deployment."
