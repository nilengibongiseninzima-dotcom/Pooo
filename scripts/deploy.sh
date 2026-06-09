#!/bin/bash
set -e

# Deployment Script for ZA Server
# Usage: bash deploy.sh <SERVER_IP> <APP_NAME>

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: bash deploy.sh <SERVER_IP> <APP_NAME>"
    exit 1
fi

SERVER_IP=$1
APP_NAME=$2
APP_USER="appuser"

echo "Deploying $APP_NAME to $SERVER_IP..."

# Connect and pull latest code
ssh -o StrictHostKeyChecking=no $APP_USER@$SERVER_IP <<'EOF'
cd ~/app
git pull origin main

# Build and start with Docker
docker-compose down || true
docker-compose up -d

# Run migrations if needed
docker-compose exec -T app npm run migrate || true

# Health check
curl -s http://localhost:3000/health || echo "Health check pending..."
EOF

echo "Deployment complete!"
