# DigitalOcean VPS Configuration for ZA Server

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# DigitalOcean Droplet - 8 CPU, 6GB RAM, 1TB SSD
resource "digitalocean_droplet" "za_server" {
  image              = "ubuntu-22-04-x64"
  name               = "za-server-prod"
  region             = "fra1" # Frankfurt (closest to ZA)
  size               = "c-8" # 8 vCPU, 16GB RAM (upgradeable)
  backups            = true
  ipv6               = true
  private_networking = true
  monitoring         = true
  tags               = ["za-server", "production", "web"]

  # Enable automated backups
  lifecycle {
    create_before_destroy = true
  }

  user_data = file("${path.module}/../scripts/cloud-init.sh")
}

# Firewall Configuration
resource "digitalocean_firewall" "za_server_fw" {
  name = "za-server-firewall"

  droplet_ids = [digitalocean_droplet.za_server.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    sources {
      addresses = ["0.0.0.0/0", "::/0"]
    }
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    sources {
      addresses = ["0.0.0.0/0", "::/0"]
    }
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    sources {
      addresses = ["0.0.0.0/0", "::/0"]
    }
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "all"
    destinations {
      addresses = ["0.0.0.0/0", "::/0"]
    }
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "all"
    destinations {
      addresses = ["0.0.0.0/0", "::/0"]
    }
  }
}

# Block Storage (additional 1TB)
resource "digitalocean_volume" "za_storage" {
  region                  = digitalocean_droplet.za_server.region
  name                    = "za-server-storage"
  size                    = 1024 # 1TB in GB
  initial_filesystem_type = "ext4"
  initial_filesystem_label = "storage"
}

resource "digitalocean_volume_attachment" "za_storage_attach" {
  droplet_id = digitalocean_droplet.za_server.id
  volume_id  = digitalocean_volume.za_storage.id
}

# Reserved IP
resource "digitalocean_reserved_ip" "za_ip" {
  droplet_id = digitalocean_droplet.za_server.id
  region     = digitalocean_droplet.za_server.region
}

output "droplet_ip" {
  value = digitalocean_droplet.za_server.ipv4_address
}

output "reserved_ip" {
  value = digitalocean_reserved_ip.za_ip.ip_address
}
