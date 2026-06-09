#!/bin/bash
set -e

# Oracle Cloud VPS Setup Script
# Usage: bash oracle-setup.sh

echo "Setting up Oracle Cloud VPS..."
echo ""
echo "Please ensure you have the following Oracle Cloud credentials:"
echo "1. Tenancy OCID"
echo "2. User OCID"
echo "3. API Key Fingerprint"
echo "4. Private Key Path"
echo ""

TF_DIR="terraform"

# Create terraform.tfvars with prompts
read -p "Enter Tenancy OCID: " TENANCY_OCID
read -p "Enter User OCID: " USER_OCID
read -p "Enter API Key Fingerprint: " FINGERPRINT
read -p "Enter Private Key Path: " PRIVATE_KEY_PATH

cat > $TF_DIR/terraform.tfvars <<EOF
tenancy_ocid     = "$TENANCY_OCID"
user_ocid        = "$USER_OCID"
fingerprint      = "$FINGERPRINT"
private_key_path = "$PRIVATE_KEY_PATH"
region           = "eu-frankfurt-1"
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

echo "Oracle Cloud VPS setup complete!"
echo "Instance is being provisioned. Check Oracle Cloud Console for status."
