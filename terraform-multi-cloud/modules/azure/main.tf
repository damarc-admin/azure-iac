// =============================================================================
// Azure Module - Virtual Machine Deployment
// =============================================================================
// Deploys a complete Azure infrastructure for the Project Tracker Flask app:
//   - Resource Group
//   - Virtual Network with Subnet
//   - Network Security Group (NSG) with security rules
//   - Public IP Address (Standard SKU)
//   - Network Interface Card (NIC)
//   - Linux Virtual Machine (Ubuntu 22.04)
//   - Custom Script Extension (app deployment)
//
// All resources are tagged with deployment metadata for tracking and auditing.
// =============================================================================

// ---------------------------------------------------------------------------
// Variables (module inputs)
// ---------------------------------------------------------------------------

variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size (e.g., Standard_D2s_v3)"
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
// Local Variables (common tags)
// ---------------------------------------------------------------------------

locals {
  common_tags = {
    Environment  = "Production"
    ManagedBy    = "Terraform"
    DeployedBy   = var.deployed_by
    DeployedDate = var.deployed_date
  }
}

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------
// Container for all Azure resources in this deployment.
// Tags are inherited by all child resources.

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg-${var.random_id}"
  location = var.location

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// Virtual Network
// ---------------------------------------------------------------------------
// Private network for the VM with a /16 address space.
// Contains a single /24 subnet for the application.

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet-${var.random_id}"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// Subnet
// ---------------------------------------------------------------------------
// Default subnet for the virtual network.
// NSG is associated to control traffic.

resource "azurerm_subnet" "main" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.1.0.0/24"]
}

// ---------------------------------------------------------------------------
// Network Security Group (NSG)
// ---------------------------------------------------------------------------
// Controls inbound and outbound traffic to the subnet and NIC.
// Two security rules are created:
//   - allow-ssh: Port 22 for SSH access
//   - allow-http: Application port for HTTP access

resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg-${var.random_id}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  // Allow SSH from specified CIDR
  security_rule {
    name                       = "allow-ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_cidr
    destination_address_prefix = "*"
  }

  // Allow HTTP from specified CIDR
  security_rule {
    name                       = "allow-http"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.app_port
    source_address_prefix      = var.app_cidr
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// NSG to Subnet Association
// ---------------------------------------------------------------------------
// Attaches the NSG to the subnet to enforce security rules.

resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

// ---------------------------------------------------------------------------
// Public IP Address
// ---------------------------------------------------------------------------
// Static public IP for accessing the VM from the internet.
// Standard SKU is used for better availability and security.

resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-pip-${var.random_id}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// Network Interface Card (NIC)
// ---------------------------------------------------------------------------
// Connects the VM to the virtual network with a public IP.
// Note: Standard SKU public IPs require explicit NSG attachment to NIC.

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic-${var.random_id}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// NIC to NSG Association
// ---------------------------------------------------------------------------
// Attaches the NSG directly to the NIC (required for Standard SKU public IPs).

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

// ---------------------------------------------------------------------------
// Linux Virtual Machine
// ---------------------------------------------------------------------------
// Ubuntu 22.04 LTS VM with Flask app deployment via Custom Script Extension.
// The VM is configured with password authentication for simplicity.

resource "azurerm_linux_virtual_machine" "main" {
  name                  = "${var.prefix}-vm-${var.random_id}"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.main.id]
  size                  = var.vm_size

  // Disable SSH key authentication, use password instead
  disable_password_authentication = false
  admin_username                  = "azureuser"
  admin_password                  = "Terraform123!"

  // Ubuntu 22.04 LTS image from Canonical
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  // Standard LRS disk for cost efficiency
  os_disk {
    name                 = "${var.prefix}-disk-${var.random_id}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// Custom Script Extension
// ---------------------------------------------------------------------------
// Executes a bash script on the VM after deployment to:
//   1. Install Python3, Git, and pip
//   2. Clone the Project Tracker application from GitHub
//   3. Install Python dependencies
//   4. Create and enable a systemd service for the Flask app
//   5. Start the application

resource "azurerm_virtual_machine_extension" "app_deploy" {
  name                 = "install-app"
  virtual_machine_id   = azurerm_linux_virtual_machine.main.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  // IMPORTANT: commandToExecute MUST be in protected_settings only
  // for security (contains no sensitive data but follows best practice)
  protected_settings = jsonencode({
    commandToExecute = <<-EOF
      #!/bin/bash
      set -e

      # Update package lists and install dependencies
      apt-get update
      apt-get install -y python3 git curl

      # Install pip (get-pip.py is more reliable than apt on Ubuntu)
      curl -sS https://bootstrap.pypa.io/get-pip.py | python3

      # Clone the Project Tracker application
      cd /opt
      git clone https://github.com/damarc-admin/project-tracker.git --branch onboard --single-branch project-tracker

      # Install Python dependencies
      # --break-system-packages: Required on newer Ubuntu with PEP 668
      # --ignore-installed blinker: Avoids conflicts with existing installations
      cd /opt/project-tracker
      pip3 install --break-system-packages --ignore-installed blinker -r requirements.txt

      # Create systemd service for automatic startup and restart
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

      # Enable and start the service
      systemctl daemon-reload
      systemctl enable project-tracker
      systemctl start project-tracker

      # Verify the service is running
      sleep 2
      systemctl status project-tracker --no-pager
    EOF
  })
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
// Provides deployment information to the user after successful deployment.

output "public_ip" {
  description = "Public IP address for accessing the application"
  value       = azurerm_public_ip.main.ip_address
}

output "private_ip" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.main.private_ip_address
}

output "vm_name" {
  description = "Name of the deployed virtual machine"
  value       = azurerm_linux_virtual_machine.main.name
}

output "resource_group" {
  description = "Name of the resource group containing all resources"
  value       = azurerm_resource_group.main.name
}

output "app_url" {
  description = "URL to access the deployed application"
  value       = "http://${azurerm_public_ip.main.ip_address}:${var.app_port}"
}
