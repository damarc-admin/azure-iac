// =============================================================================
// Terraform Variables - Project Tracker VM Deployment
// =============================================================================
// This file defines all configurable input variables for the deployment.
// Override defaults by setting values in terraform.tfvars
// =============================================================================

// ---------------------------------------------------------------------------
// Resource Configuration
// ---------------------------------------------------------------------------
// Core resource settings

// Azure region where all resources will be deployed
// Common values: eastus, westus2, canadacentral, uksouth, westeurope
variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "canadacentral"
}

// Name of the Azure Resource Group that will contain all resources
// Resource groups help organize and manage related resources
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "project-tracker-rg"
}

// ---------------------------------------------------------------------------
// Naming Conventions
// ---------------------------------------------------------------------------
// Resource naming configuration

// Prefix used for naming resources
// Changing this allows multiple deployments in the same subscription
variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "project-tracker"
}

// DNS label for the public IP address
// Creates FQDN: <dns_label>.<location>.cloudapp.azure.com
// Must be unique within the Azure region
variable "dns_label" {
  description = "DNS label for public IP (creates FQDN: prefix.location.cloudapp.azure.com)"
  type        = string
  default     = "project-tracker"
}

// ---------------------------------------------------------------------------
// Virtual Network Configuration
// ---------------------------------------------------------------------------
// Network infrastructure settings

// Name of the virtual network
// VNet provides private network connectivity within Azure
variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "project-tracker-vnet"
}

// Name of the subnet within the virtual network
// Subnets segment the network and enable NSG application
variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "default"
}

// Name of the network security group
// NSG acts as a firewall with inbound/outbound rules
variable "nsg_name" {
  description = "Name of the network security group"
  type        = string
  default     = "project-tracker-vm-nsg"
}

// Name of the network interface
// NIC connects the VM to the virtual network
variable "nic_name" {
  description = "Name of the network interface"
  type        = string
  default     = "project-tracker-vm-nic"
}

// Name of the public IP address
// Public IP enables internet access to the VM
variable "public_ip_name" {
  description = "Name of the public IP address"
  type        = string
  default     = "project-tracker-pip"
}

// ---------------------------------------------------------------------------
// Virtual Machine Configuration
// ---------------------------------------------------------------------------
// VM sizing and authentication settings

// Name of the virtual machine
// This is also used as the computer name within the OS
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "project-tracker-vm"
}

// VM size determines CPU, memory, and disk capacity
// Common sizes:
//   Standard_B2s  - 2 vCPU, 4GB RAM (burstable, cheaper)
//   Standard_D2s_v3 - 2 vCPU, 8GB RAM (general purpose)
//   Standard_D4s_v3 - 4 vCPU, 16GB RAM (larger workloads)
variable "vm_size" {
  description = "Size of the virtual machine (e.g., Standard_D2s_v3)"
  type        = string
  default     = "Standard_D2s_v3"
}

// Administrator username for the VM
// Used for SSH and console access
// Note: 'admin', 'root', 'administrator' are reserved and not allowed
variable "admin_username" {
  description = "Administrator username for the virtual machine"
  type        = string
  default     = "azureuser"
}

// Administrator password for the VM
// IMPORTANT: Must be set in terraform.tfvars (marked as sensitive)
// Password requirements: 12-123 chars, mixed case, numbers, special chars
variable "admin_password" {
  description = "Administrator password for the virtual machine"
  type        = string
  sensitive   = true
  default     = ""
}

// SSH public key for authentication
// Leave empty to auto-generate an RSA key pair
// Format: "ssh-rsa AAAA..." or paste contents of ~/.ssh/id_rsa.pub
variable "ssh_public_key" {
  description = "SSH public key for authentication (leave empty to auto-generate)"
  type        = string
  default     = ""
}

// ---------------------------------------------------------------------------
// Application Configuration
// ---------------------------------------------------------------------------
// Flask application settings

// Port number where the Flask application listens
// Default is 5000 (Flask's default development port)
// Must match the port configured in the Flask app
variable "app_service_port" {
  description = "Port on which the Flask application runs"
  type        = string
  default     = "5000"
}

// Bash script executed by Custom Script Extension after VM creation
// This script:
//   1. Installs Python 3, git, and pip
//   2. Clones the Project Tracker repository from GitHub
//   3. Installs Python dependencies (Flask, pytest)
//   4. Creates a systemd service for auto-start
//   5. Starts the application
//
// IMPORTANT: The Flask app must bind to 0.0.0.0 (not 127.0.0.1)
// to accept connections from the public IP address.
variable "install_script" {
  description = "Bash script to install and configure the application"
  type        = string
  sensitive   = true

  default = <<-EOT
#!/bin/bash
set -e

# Update package lists and install required packages
# - python3: Python runtime environment
# - git: Version control for cloning repository
# - curl: HTTP client for downloading pip installer
apt-get update
apt-get install -y python3 git curl

# Install pip (Python package manager)
# Using get-pip.py because python3-pip package may not be available
# in Ubuntu 22.04 minimal images
curl -sS https://bootstrap.pypa.io/get-pip.py | python3

# Clone the Project Tracker application from GitHub
# --branch onboard: Uses the specific branch for this deployment
# --single-branch: Only clone the specified branch (faster)
cd /opt
git clone https://github.com/damarc-admin/project-tracker.git --branch onboard --single-branch project-tracker

# Install Python dependencies from requirements.txt
# --break-system-packages: Required for pip to install in system Python
# --ignore-installed blinker: Avoids conflicts with system-installed blinker
cd /opt/project-tracker
pip3 install --break-system-packages --ignore-installed blinker -r requirements.txt

# Create systemd service file for automatic startup
# systemd ensures the app starts on boot and restarts on failure
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

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable project-tracker
systemctl start project-tracker

echo "Application deployed successfully"
EOT
}

// ---------------------------------------------------------------------------
// Tags
// ---------------------------------------------------------------------------
// Metadata applied to all resources for organization and billing

// Tags are key-value pairs that help with:
// - Resource organization (Environment, Application)
// - Cost tracking (Cost Center, Owner)
// - Automation (ManagedBy)
// - Compliance and security requirements
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    Application = "Project Tracker"
    ManagedBy   = "Terraform"
  }
}
