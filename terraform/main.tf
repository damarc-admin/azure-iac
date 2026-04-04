// =============================================================================
// Azure Terraform Configuration - Project Tracker VM Deployment
// =============================================================================
// Purpose: Deploy a Flask-based Project Tracker application on Azure VM
// 
// Architecture:
//   Internet -> Public IP -> NIC -> VM (Flask App on port 5000)
// 
// Key Features:
//   - Ubuntu 22.04 LTS VM with Standard_D2s_v3 (2 vCPU, 8GB RAM)
//   - Standard SKU public IP (static) for production use
//   - Network Security Group with firewall rules
//   - Automatic app installation via Custom Script Extension
// 
// Important Notes:
//   - Flask app must use host='0.0.0.0' to be externally accessible
//   - Standard SKU public IP requires explicit NSG attachment to NIC
//   - SSH key is auto-generated if not provided
// =============================================================================

// ---------------------------------------------------------------------------
// Terraform and Provider Configuration
// ---------------------------------------------------------------------------
// Terraform Block: Specifies required version and providers
// - azurerm: Azure resource provider
// - random: For generating random values (if needed)
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

// Azure Provider Configuration
// The features {} block is required for azurerm provider v3.x
provider "azurerm" {
  features {}
}

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------
// Resource Group: Logical container for all Azure resources
// All other resources will be deployed inside this group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

// ---------------------------------------------------------------------------
// Virtual Network (VNet)
// ---------------------------------------------------------------------------
// VNet: Private network in Azure for VM connectivity
// - address_space: IP range for the entire network (10.0.0.0/16 = 65,536 IPs)
// - All subnets must fall within this address space
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/16"]           // Network range: 10.0.0.0 - 10.0.255.255
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

// ---------------------------------------------------------------------------
// Subnet
// ---------------------------------------------------------------------------
// Subnet: Logical partition of the VNet
// - Subnet must have address space within VNet's address_space
// - VMs are deployed into subnets
resource "azurerm_subnet" "main" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]         // Subnet range: 10.0.0.0 - 10.0.0.255 (256 IPs)
}

// ---------------------------------------------------------------------------
// Network Security Group (NSG)
// ---------------------------------------------------------------------------
// NSG: Firewall rules to filter network traffic
// - Acts as a virtual firewall for the VM
// - Rules are evaluated by priority (lower number = higher priority)
// - Default rules block all traffic if no matching rule is found
resource "azurerm_network_security_group" "main" {
  name                = var.nsg_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  // Security Rule 1: SSH Access
  // Allows remote administration of the VM via SSH on port 22
  // Priority 1001: Evaluated first among our custom rules
  security_rule {
    name                       = "allow-ssh"
    priority                   = 1001
    direction                  = "Inbound"        // Traffic coming INTO the VM
    access                     = "Allow"          // Allow this traffic
    protocol                   = "Tcp"            // TCP protocol (not UDP)
    source_port_range          = "*"              // Any source port (clients use ephemeral ports)
    destination_port_range     = "22"             // SSH default port
    source_address_prefix      = "Internet"        // Allow from anywhere on internet
    destination_address_prefix = "*"              // Allow to any destination IP
  }

  // Security Rule 2: HTTP Access (Flask Application)
  // Allows web traffic to the Flask application on port 5000
  // Priority 1002: Evaluated after SSH rule
  security_rule {
    name                       = "allow-http"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.app_service_port  // Default: 5000
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

// ---------------------------------------------------------------------------
// NSG to Subnet Association
// ---------------------------------------------------------------------------
// Associates the NSG with the subnet for network-level security
// Note: This is separate from NIC-level NSG attachment
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

// ---------------------------------------------------------------------------
// Public IP Address
// ---------------------------------------------------------------------------
// Public IP: Static IP address for internet accessibility
// - allocation_method: "Static" ensures IP doesn't change on reboot
// - sku: "Standard" is required for:
//   1. Zone-redundant deployments (future)
//   2. NSG attachment to NIC (required for this setup)
//   3. Production environments
resource "azurerm_public_ip" "main" {
  name                = var.public_ip_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"              // Static IP (persists after reboot)
  sku                 = "Standard"           // Standard SKU (not Basic)

  // DNS label creates FQDN: <dns_label>.<location>.cloudapp.azure.com
  domain_name_label = var.dns_label

  tags = var.tags
}

// ---------------------------------------------------------------------------
// Network Interface (NIC)
// ---------------------------------------------------------------------------
// NIC: Virtual network interface connecting VM to Azure network
// - Each NIC can have one public IP attached
// - Private IP is assigned via DHCP from the subnet
// - NIC is the attachment point for NSGs when using Standard SKU public IPs
resource "azurerm_network_interface" "main" {
  name                = var.nic_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  // IP Configuration: Defines how the NIC gets its IP addresses
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.main.id           // Private subnet
    private_ip_address_allocation = "Dynamic"                        // DHCP-assigned
    public_ip_address_id          = azurerm_public_ip.main.id        // Attach public IP
  }

  tags = var.tags
}

// ---------------------------------------------------------------------------
// NIC to NSG Association
// ---------------------------------------------------------------------------
// Attaches NSG directly to the NIC
// REQUIRED: For Standard SKU public IPs, NSG must be attached to NIC
// This is in addition to (not instead of) subnet-level NSG
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

// ---------------------------------------------------------------------------
// Virtual Machine
// ---------------------------------------------------------------------------
// VM: Azure compute resource running Ubuntu Linux
// - Size (Standard_D2s_v3): 2 vCPUs, 8GB RAM
// - OS: Ubuntu 22.04 LTS from Canonical
// - Storage: Standard SSD (128GB)
resource "azurerm_linux_virtual_machine" "main" {
  name                  = var.vm_name
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.main.id]  // Connect to NIC
  size                  = var.vm_size                         // Standard_D2s_v3

  // Authentication: Allow both password and SSH key
  // disable_password_authentication = false means both methods work
  disable_password_authentication = false

  // Admin Account: Credentials for logging into the VM
  admin_username = var.admin_username                        // Default: azureuser
  admin_password = var.admin_password                        // Set in terraform.tfvars

  // OS Image: Ubuntu 22.04 LTS (Jammy Jellyfish)
  // Publisher: Canonical (official Ubuntu publisher)
  // Offer: 0001-com-ubuntu-server-jammy (correct offer for 22.04)
  // SKU: 22_04-lts (Long Term Support version)
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  // OS Disk: Where the operating system is installed
  // - Standard_LRS: Standard HDD (cheapest, adequate for dev/test)
  // - Premium_LRS: Premium SSD (better performance, higher cost)
  // - caching = ReadWrite: Optimize for OS disk performance
  os_disk {
    name                 = "${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  // SSH Key: Used for secure shell access to the VM
  // If ssh_public_key is empty, a new key pair is generated
  // The private key will be shown in terraform output
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key == "" ? tls_private_key.main[0].public_key_openssh : var.ssh_public_key
  }

  tags = var.tags

  // Explicit dependency: Ensure NSG is attached before VM is created
  // This prevents potential race conditions
  depends_on = [
    azurerm_network_interface_security_group_association.main
  ]
}

// ---------------------------------------------------------------------------
// TLS Private Key (Auto-Generated)
// ---------------------------------------------------------------------------
// Generates RSA key pair if ssh_public_key is not provided
// - algorithm: RSA (widely supported)
// - rsa_bits: 4096 (strong encryption, recommended)
// - count: Only create if ssh_public_key is empty
resource "tls_private_key" "main" {
  count     = var.ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

// ---------------------------------------------------------------------------
// Custom Script Extension
// ---------------------------------------------------------------------------
// Extension: Executes bash script to install and configure the application
// Runs AFTER the VM is created and provisioned
// 
// IMPORTANT: The Flask application MUST bind to 0.0.0.0 (not 127.0.0.1)
// to accept connections from the public IP address.
resource "azurerm_virtual_machine_extension" "main" {
  name                         = "install-app"
  virtual_machine_id            = azurerm_linux_virtual_machine.main.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.1"
  automatic_upgrade_enabled    = false

  // Settings: Script to execute (visible in Azure portal)
  settings = jsonencode({
    commandToExecute = "bash -c '${var.install_script}'"
  })

  // Protected Settings: Sensitive data (not visible in portal)
  // Both commandToExecute fields must match for the extension to run
  protected_settings = jsonencode({
    commandToExecute = "bash -c '${var.install_script}'"
  })
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
// See outputs.tf for all output definitions
