// =============================================================================
// GCP Module - Virtual Machine Deployment
// =============================================================================
// Deploys a complete GCP infrastructure for the Project Tracker Flask app:
//   - Firewall Rules (SSH and HTTP)
//   - Static External IP Address
//   - Compute Engine Instance (Ubuntu 22.04)
//
// All resources are labeled with deployment metadata for tracking and auditing.
// =============================================================================

// ---------------------------------------------------------------------------
// Variables (module inputs)
// ---------------------------------------------------------------------------

variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "region" {
  description = "GCP region for deployment"
  type        = string
}

variable "machine_type" {
  description = "GCP machine type (e.g., e2-standard-2)"
  type        = string
}

variable "app_port" {
  description = "Application port (Flask default is 5000)"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR block for SSH access (0.0.0.0/0 for anywhere)"
  type        = string
}

variable "app_cidr" {
  description = "CIDR block for application access (0.0.0.0/0 for anywhere)"
  type        = string
}

variable "random_id" {
  description = "Unique random ID for resource naming"
  type        = string
}

variable "deployed_by" {
  description = "Username of the person deploying"
  type        = string
  default     = "unknown"
}

variable "deployed_date" {
  description = "Date of deployment (YYYY-MM-DD)"
  type        = string
  default     = "unknown"
}

// ---------------------------------------------------------------------------
// Common Labels
// ---------------------------------------------------------------------------
// Applied to all resources for consistent labeling across GCP services.

locals {
  common_labels = {
    environment  = "production"
    managed_by   = "terraform"
    deployed_by  = var.deployed_by
    deployed_date = var.deployed_date
  }
}

// ---------------------------------------------------------------------------
// Firewall Rules
// ---------------------------------------------------------------------------
// Network-level security rules controlling ingress traffic.
// - allow-ssh: Permits SSH access on port 22
// - allow-http: Permits application access on the configured port

resource "google_compute_firewall" "ssh" {
  name          = "${var.prefix}-allow-ssh-${var.random_id}"
  network       = "default"
  description   = "Allow SSH access"
  target_tags   = ["ssh-server"]
  source_ranges = [var.ssh_cidr]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  labels = local.common_labels
}

resource "google_compute_firewall" "http" {
  name          = "${var.prefix}-allow-http-${var.random_id}"
  network       = "default"
  description   = "Allow HTTP access"
  target_tags   = ["http-server"]
  source_ranges = [var.app_cidr]

  allow {
    protocol = "tcp"
    ports    = [var.app_port]
  }

  labels = local.common_labels
}

// ---------------------------------------------------------------------------
// Static External IP Address
// ---------------------------------------------------------------------------
// Reserved static IP address for the instance.
// Persists even when the instance is stopped/deleted.

resource "google_compute_address" "main" {
  name         = "${var.prefix}-ip-${var.random_id}"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "STANDARD"

  labels = local.common_labels
}

// ---------------------------------------------------------------------------
// Compute Engine Instance
// ---------------------------------------------------------------------------
// Ubuntu 22.04 LTS instance with startup script for app deployment.
// Instance tags are used by firewall rules to identify traffic.

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

    // Attach the static IP address
    access_config {
      nat_ip = google_compute_address.main.address
    }
  }

  // Metadata startup script runs on first boot
  metadata = {
    startup-script = <<-EOF
#!/bin/bash
set -e

# Update packages and install dependencies
apt-get update
apt-get install -y python3 git curl

# Install pip
curl -sS https://bootstrap.pypa.io/get-pip.py | python3

# Clone Project Tracker application
cd /opt
git clone https://github.com/damarc-admin/project-tracker.git --branch onboard --single-branch project-tracker

# Install dependencies
cd /opt/project-tracker
pip3 install --break-system-packages --ignore-installed blinker -r requirements.txt

# Create systemd service
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
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Enable and start service
systemctl daemon-reload
systemctl enable project-tracker
systemctl start project-tracker
EOF
  }

  // Instance tags must match firewall target tags
  tags = ["http-server", "ssh-server"]

  labels = local.common_labels

  // Service account configuration (if needed)
  // service_account {
  //   scopes = ["cloud-platform"]
  // }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output "public_ip" {
  description = "Public IP address for accessing the application"
  value       = google_compute_address.main.address
}

output "instance_name" {
  description = "Name of the deployed instance"
  value       = google_compute_instance.main.name
}

output "zone" {
  description = "Zone where the instance is deployed"
  value       = google_compute_instance.main.zone
}

output "app_url" {
  description = "URL to access the deployed application"
  value       = "http://${google_compute_address.main.address}:${var.app_port}"
}
