# Oracle Cloud VPS Configuration for ZA Server

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

# Compartment (use existing or create)
data "oci_identity_compartments" "compartments" {
  compartment_id = var.tenancy_ocid
  filter {
    name   = "name"
    values = ["Default"]
  }
}

# VCN (Virtual Cloud Network)
resource "oci_core_vcn" "za_vcn" {
  compartment_id = data.oci_identity_compartments.compartments.compartments[0].id
  display_name   = "za-server-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
}

# Internet Gateway
resource "oci_core_internet_gateway" "za_igw" {
  compartment_id = data.oci_identity_compartments.compartments.compartments[0].id
  vcn_id         = oci_core_vcn.za_vcn.id
  display_name   = "za-igw"
}

# Subnet
resource "oci_core_subnet" "za_subnet" {
  compartment_id      = data.oci_identity_compartments.compartments.compartments[0].id
  vcn_id              = oci_core_vcn.za_vcn.id
  cidr_block          = "10.0.1.0/24"
  display_name        = "za-subnet"
  dns_label           = "zasubnet"
  security_list_ids   = [oci_core_security_list.za_sl.id]
}

# Security List (Firewall)
resource "oci_core_security_list" "za_sl" {
  compartment_id = data.oci_identity_compartments.compartments.compartments[0].id
  vcn_id         = oci_core_vcn.za_vcn.id
  display_name   = "za-security-list"

  # SSH
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # HTTP
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  # HTTPS
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Egress - Allow all outbound
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Instance - 8 OCPUs, 6GB RAM, 1TB storage
resource "oci_core_instance" "za_instance" {
  availability_domain = data.oci_core_availability_domains.ad.availability_domains[0].name
  compartment_id      = data.oci_identity_compartments.compartments.compartments[0].id
  display_name        = "za-server-prod"
  shape               = "VM.Standard.E4.Flex"

  shape_config {
    ocpus         = 8
    memory_in_gbs = 6
  }

  create_vnic_details {
    subnet_id       = oci_core_subnet.za_subnet.id
    display_name    = "za-vnic"
    assign_public_ip = true
  }

  source_details {
    source_type = "IMAGE"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  user_data = base64encode(file("${path.module}/../scripts/cloud-init.sh"))
}

# Block Storage Volume (1TB)
resource "oci_core_volume" "za_storage" {
  availability_domain = data.oci_core_availability_domains.ad.availability_domains[0].name
  compartment_id      = data.oci_identity_compartments.compartments.compartments[0].id
  display_name        = "za-storage-1tb"
  size_in_gbs         = 1024
}

resource "oci_core_volume_attachment" "za_storage_attach" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.za_instance.id
  volume_id       = oci_core_volume.za_storage.id
  device          = "/dev/oracleoci/oraclevdb"
}

# Data sources
data "oci_core_availability_domains" "ad" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id = data.oci_identity_compartments.compartments.compartments[0].id
  operating_system = "Canonical Ubuntu"
  operating_system_version = "22.04"
  filter {
    name   = "display_name"
    values = ["Canonical-Ubuntu-22.04"]
  }
}

output "instance_public_ip" {
  value = oci_core_instance.za_instance.public_ip
}

output "instance_private_ip" {
  value = oci_core_instance.za_instance.private_ip
}
