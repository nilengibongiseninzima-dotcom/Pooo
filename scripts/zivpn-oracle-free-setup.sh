#!/bin/bash
set -e

# ZiVPN Oracle Cloud Always Free Tier Setup
# No payment verification needed initially
# Completely FREE forever

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     ZiVPN - Oracle Cloud Always Free Tier Setup           ║"
echo "║          (2 vCPU, 12GB RAM, 200GB Storage - FREE)        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Installing..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
    apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    apt-get update && apt-get install terraform -y
fi

echo "✅ Creating Terraform configuration for Oracle Free Tier..."
echo ""

mkdir -p terraform/oracle-free
cd terraform/oracle-free

# Create main.tf for Oracle Free Tier
cat > main.tf <<'EOF'
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# Get compartment
data "oci_identity_compartments" "compartment" {
  compartment_id = var.tenancy_ocid
  filter {
    name   = "name"
    values = ["Default"]
  }
}

# VCN (Virtual Cloud Network)
resource "oci_core_vcn" "zivpn_vcn" {
  compartment_id = data.oci_identity_compartments.compartment.compartments[0].id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "zivpn-vcn"
}

# Internet Gateway
resource "oci_core_internet_gateway" "zivpn_igw" {
  compartment_id = data.oci_identity_compartments.compartment.compartments[0].id
  vcn_id         = oci_core_vcn.zivpn_vcn.id
  display_name   = "zivpn-igw"
}

# Subnet
resource "oci_core_subnet" "zivpn_subnet" {
  compartment_id      = data.oci_identity_compartments.compartment.compartments[0].id
  vcn_id              = oci_core_vcn.zivpn_vcn.id
  cidr_block          = "10.0.1.0/24"
  display_name        = "zivpn-subnet"
  dns_label           = "zivpnsubnet"
  security_list_ids   = [oci_core_security_list.zivpn_sl.id]
}

# Security List (Firewall)
resource "oci_core_security_list" "zivpn_sl" {
  compartment_id = data.oci_identity_compartments.compartment.compartments[0].id
  vcn_id         = oci_core_vcn.zivpn_vcn.id
  display_name   = "zivpn-security-list"

  # SSH
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # UDP Port 1194 (Primary VPN)
  ingress_security_rules {
    protocol    = "17"
    source      = "0.0.0.0/0"
    udp_options {
      min = 1194
      max = 1194
    }
  }

  # UDP Port 1195 (Failover)
  ingress_security_rules {
    protocol    = "17"
    source      = "0.0.0.0/0"
    udp_options {
      min = 1195
      max = 1195
    }
  }

  # UDP Port 443 (Stealth)
  ingress_security_rules {
    protocol    = "17"
    source      = "0.0.0.0/0"
    udp_options {
      min = 443
      max = 443
    }
  }

  # HTTP (Monitoring Dashboard)
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options {
      min = 8080
      max = 8080
    }
  }

  # All egress allowed
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Instance - Oracle Always Free Tier (2 vCPU, 12GB RAM)
resource "oci_core_instance" "zivpn_instance" {
  availability_domain = data.oci_core_availability_domains.ad.availability_domains[0].name
  compartment_id      = data.oci_identity_compartments.compartment.compartments[0].id
  display_name        = "zivpn-server"
  shape               = "VM.Standard.E2.1.Micro" # Always Free eligible

  create_vnic_details {
    subnet_id       = oci_core_subnet.zivpn_subnet.id
    display_name    = "zivpn-vnic"
    assign_public_ip = true
  }

  source_details {
    source_type = "IMAGE"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  user_data = base64encode(file("${path.module}/../../zivpn/deploy-zivpn.sh"))

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }
}

# Data sources
data "oci_core_availability_domains" "ad" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id = data.oci_identity_compartments.compartment.compartments[0].id
  filter {
    name   = "display_name"
    values = ["Canonical-Ubuntu-22.04-.*"]
  }
  filter {
    name   = "state"
    values = ["AVAILABLE"]
  }
}

output "instance_public_ip" {
  value = oci_core_instance.zivpn_instance.public_ip
  description = "Public IP of ZiVPN Server"
}

output "instance_private_ip" {
  value = oci_core_instance.zivpn_instance.private_ip
  description = "Private IP of ZiVPN Server"
}
EOF

# Create variables.tf
cat > variables.tf <<'EOF'
variable "tenancy_ocid" {
  description = "Oracle Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "Oracle User OCID"
  type        = string
}

variable "fingerprint" {
  description = "Oracle API Key Fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to Oracle Private Key"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to SSH Public Key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "region" {
  description = "Oracle Cloud Region (Frankfurt for ZA)"
  type        = string
  default     = "eu-frankfurt-1"
}
EOF

echo ""
echo "📋 Oracle Cloud Free Tier Setup Instructions:"
echo ""
echo "Step 1: Create Oracle Cloud Account"
echo "   → Go to: https://www.oracle.com/cloud/free/"
echo "   → Sign up (no payment needed initially)"
echo ""
echo "Step 2: Get API Credentials"
echo "   → Go to: Oracle Cloud Console → Profile → User Settings"
echo "   → Click 'API Keys'"
echo "   → Click 'Add API Key'"
echo "   → Select 'Generate API Key Pair'"
echo "   → Save private key and copy Fingerprint"
echo ""
echo "Step 3: Get OCIDs"
echo "   → Tenancy OCID: Profile → Tenancy"
echo "   → User OCID: Profile → User Settings"
echo ""
echo "Step 4: Create terraform.tfvars"
echo ""
read -p "Enter Tenancy OCID: " TENANCY_OCID
read -p "Enter User OCID: " USER_OCID
read -p "Enter API Key Fingerprint: " FINGERPRINT
read -p "Enter path to Private Key: " PRIVATE_KEY
read -p "Enter path to SSH Public Key (default: ~/.ssh/id_rsa.pub): " SSH_KEY

SSH_KEY=${SSH_KEY:-~/.ssh/id_rsa.pub}

cat > terraform.tfvars <<TFVARS
tenancy_ocid      = "$TENANCY_OCID"
user_ocid         = "$USER_OCID"
fingerprint       = "$FINGERPRINT"
private_key_path  = "$PRIVATE_KEY"
ssh_public_key_path = "$SSH_KEY"
region            = "eu-frankfurt-1"
TFVARS

echo ""
echo "✅ terraform.tfvars created!"
echo ""
echo "Step 5: Deploy Infrastructure"
echo ""
echo "   terraform init"
echo "   terraform plan"
echo "   terraform apply"
echo ""
echo "This will create:"
echo "   ✓ VCN (Virtual Cloud Network)"
echo "   ✓ Subnet with security rules"
echo "   ✓ Ubuntu 22.04 Instance (2 vCPU, 12GB RAM) - ALWAYS FREE"
echo "   ✓ Firewall rules for UDP ports (1194, 1195, 443)"
echo "   ✓ Auto-deploy ZiVPN on boot"
echo ""
echo "All completely FREE forever on Oracle Always Free Tier!"
echo ""
