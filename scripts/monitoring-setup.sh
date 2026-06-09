#!/bin/bash
set -e

# Monitoring Setup Script
# Sets up Prometheus and Grafana for server monitoring

echo "Setting up monitoring..."

MONITOR_DIR="/home/appuser/monitoring"

sudo mkdir -p $MONITOR_DIR

# Create docker-compose for monitoring
cat > $MONITOR_DIR/docker-compose.yml <<'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    restart: always

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    restart: always

volumes:
  prometheus_data:
  grafana_data:
EOF

# Create Prometheus config
cat > $MONITOR_DIR/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']
EOF

# Start monitoring stack
cd $MONITOR_DIR
sudo docker-compose up -d

echo "Monitoring setup complete!"
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000 (admin/admin)"
