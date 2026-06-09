#!/bin/bash
set -e

# DigitalOcean VPS Setup Script
# Usage: bash digitalocean-setup.sh <DO_TOKEN>

if [ -z "$1" ]; then
    echo "Usage: bash digitalocean-setup.sh <DIGITALOCEAN_TOKEN>"
    exit 1
fi

DO_TOKEN=$1
TF_DIR="terraform"

echo "Setting up DigitalOcean VPS..."

# Create terraform.tfvars
cat > $TF_DIR/terraform.tfvars <<EOF
do_token = "$DO_TOKEN"
EOF

echo "Initializing Terraform..."
cd $TF_DIR
terraform init

echo "Planning infrastructure..."
terraform plan -out=tfplan

echo "Applying infrastructure..."
terraform apply tfplan

echo "Getting outputs..."
terraform output

echo "DigitalOcean VPS setup complete!"
echo "Droplet is being provisioned. Check DigitalOcean dashboard for status."
