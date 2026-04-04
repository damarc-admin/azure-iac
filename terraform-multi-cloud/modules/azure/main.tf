// =============================================================================
// Azure Module - Virtual Machine Deployment
// =============================================================================

// ---------------------------------------------------------------------------
// Variables (module inputs)
// ---------------------------------------------------------------------------

variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size"
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
// Resource Group
// ---------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg-${var.random_id}"
  location = var.location

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

// ---------------------------------------------------------------------------
// Virtual Network
// ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet-${var.random_id}"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = "Production"
  }
}

// ---------------------------------------------------------------------------
// Subnet
// ---------------------------------------------------------------------------

resource "azurerm_subnet" "main" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.1.0.0/24"]
}

// ---------------------------------------------------------------------------
// Network Security Group
// ---------------------------------------------------------------------------

resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg-${var.random_id}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                    = "Allow"
    protocol                  = "Tcp"
    source_port_range         = "*"
    destination_port_range     = "22"
    source_address_prefix     = var.ssh_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    priority                   = 1002
    direction                  = "Inbound"
    access                    = "Allow"
    protocol                  = "Tcp"
    source_port_range         = "*"
    destination_port_range     = var.app_port
    source_address_prefix     = var.app_cidr
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Production"
  }
}

// ---------------------------------------------------------------------------
// NSG Association
// ---------------------------------------------------------------------------

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

// ---------------------------------------------------------------------------
// Public IP
// ---------------------------------------------------------------------------

resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-pip-${var.random_id}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Production"
  }
}

// ---------------------------------------------------------------------------
// Network Interface
// ---------------------------------------------------------------------------

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

  tags = {
    Environment = "Production"
  }
}

// ---------------------------------------------------------------------------
// NIC NSG Association
// ---------------------------------------------------------------------------

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

// ---------------------------------------------------------------------------
// Virtual Machine
// ---------------------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "main" {
  name                  = "${var.prefix}-vm-${var.random_id}"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.main.id]
  size                  = var.vm_size

  disable_password_authentication = false
  admin_username                = "azureuser"
  admin_password                = "Terraform123!"

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.prefix}-disk-${var.random_id}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags = {
    Environment = "Production"
  }
}

// ---------------------------------------------------------------------------
// Custom Script Extension
// ---------------------------------------------------------------------------

resource "azurerm_virtual_machine_extension" "main" {
  name                         = "install-app"
  virtual_machine_id             = azurerm_linux_virtual_machine.main.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.1"

  settings = jsonencode({
    commandToExecute = <<-EOF
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
  })

  protected_settings = jsonencode({
    commandToExecute = "bash"
  })
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output "public_ip" {
  description = "Public IP address"
  value       = azurerm_public_ip.main.ip_address
}

output "private_ip" {
  description = "Private IP address"
  value       = azurerm_network_interface.main.private_ip_address
}

output "vm_name" {
  description = "Virtual machine name"
  value       = azurerm_linux_virtual_machine.main.name
}

output "resource_group" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}
