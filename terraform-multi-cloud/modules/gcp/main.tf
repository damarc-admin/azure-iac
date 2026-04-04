// =============================================================================
// GCP Module - Virtual Machine Deployment
// =============================================================================

// ---------------------------------------------------------------------------
// Variables (module inputs)
// ---------------------------------------------------------------------------

variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "machine_type" {
  description = "GCP machine type"
  type        = string
}

variable "app_port" {
  description = "Application port"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR for SSH access"
  type        = string
}

variable "app_cidr" {
  description = "CIDR for app access"
  type        = string
}

variable "random_id" {
  description = "Random ID for unique naming"
  type        = string
}

// ---------------------------------------------------------------------------
// Firewall Rules
// ---------------------------------------------------------------------------

resource "google_compute_firewall" "ssh" {
  name        = "${var.prefix}-allow-ssh-${var.random_id}"
  network     = "default"
  description = "Allow SSH access"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.ssh_cidr]
}

resource "google_compute_firewall" "http" {
  name        = "${var.prefix}-allow-http-${var.random_id}"
  network     = "default"
  description = "Allow HTTP access"

  allow {
    protocol = "tcp"
    ports    = [var.app_port]
  }

  source_ranges = [var.app_cidr]
}

// ---------------------------------------------------------------------------
// Static IP Address
// ---------------------------------------------------------------------------

resource "google_compute_address" "main" {
  name         = "${var.prefix}-ip-${var.random_id}"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
}

// ---------------------------------------------------------------------------
// VM Instance
// ---------------------------------------------------------------------------

resource "google_compute_instance" "main" {
  name         = "${var.prefix}-vm-${var.random_id}"
  machine_type = var.machine_type
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20240126"
      size  = 20
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.main.address
    }
  }

  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      set -e
      apt-get update
      apt-get install -y python3 git curl
      curl -sS https://bootstrap.pypa.io/get-pip.py | python3
      cd /opt
      git clone https://github.com/damarc-admin/project-tracker.git --branch onboard --single-branch project-tracker
      cd /opt/project-tracker
      pip3 install --break-system-packages --ignore-installed blinker -r requirements.txt
      cat > /etc/systemd/system/project-tracker.service << 'SERVICEEOF'
[Unit]
Description=Project Tracker Flask Application
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/opt/project-tracker
ExecStart=/usr/bin/python3 /opt/project-tracker/app.py
Restart=always
[Install]
WantedBy=multi-user.target
SERVICEEOF
      systemctl daemon-reload
      systemctl enable project-tracker
      systemctl start project-tracker
    EOF
  }

  tags = ["http-server", "ssh-server"]

  labels = {
    environment = "production"
    managed_by   = "terraform"
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output "public_ip" {
  description = "Public IP address"
  value       = google_compute_address.main.address
}

output "instance_name" {
  description = "Instance name"
  value       = google_compute_instance.main.name
}

output "zone" {
  description = "Instance zone"
  value       = google_compute_instance.main.zone
}
