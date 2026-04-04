// =============================================================================
// Terraform Outputs - Project Tracker VM Deployment
// =============================================================================
// This file defines values that are displayed after successful deployment
// and can be queried using 'terraform output' command
// =============================================================================

// ---------------------------------------------------------------------------
// Resource Identifiers
// ---------------------------------------------------------------------------
// Resource names for reference and management

// Name of the resource group containing all deployed resources
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

// Name of the virtual network
output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

// Name of the subnet within the virtual network
output "subnet_name" {
  description = "Name of the subnet"
  value       = azurerm_subnet.main.name
}

// Name of the network security group (firewall)
output "network_security_group_name" {
  description = "Name of the network security group"
  value       = azurerm_network_security_group.main.name
}

// Name of the network interface connecting VM to network
output "network_interface_name" {
  description = "Name of the network interface"
  value       = azurerm_network_interface.main.name
}

// Name of the virtual machine
output "virtual_machine_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.main.name
}

// ---------------------------------------------------------------------------
// Network Information
// ---------------------------------------------------------------------------
// IP addresses and network endpoints

// Public IP address assigned to the VM
// This is the IP to use for accessing the application from the internet
// Format: IPv4 address (e.g., "20.42.115.78")
output "public_ip_address" {
  description = "Public IP address of the deployed VM"
  value       = azurerm_public_ip.main.ip_address
}

// Fully Qualified Domain Name (FQDN) of the public IP
// Alternative to IP address - easier to remember
// Format: dnslabel.location.cloudapp.azure.com
// Example: project-tracker.canadacentral.cloudapp.azure.com
output "public_ip_fqdn" {
  description = "Fully qualified domain name of the public IP"
  value       = azurerm_public_ip.main.fqdn
}

// Private IP address assigned to the VM's NIC
// Only accessible within the virtual network
// Format: 10.0.0.x (within subnet range)
output "private_ip_address" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.main.private_ip_address
}

// ---------------------------------------------------------------------------
// SSH Key Information
// ---------------------------------------------------------------------------
// SSH credentials for VM access

// SSH private key (only shown if auto-generated)
// IMPORTANT: Save this securely - it will not be shown again
// Use with: ssh -i <private_key> azureuser@<public_ip>
output "ssh_private_key" {
  description = "SSH private key (if auto-generated, save this securely)"
  value       = var.ssh_public_key == "" ? tls_private_key.main[0].private_key_pem : ""
  sensitive   = true
}

// SSH public key used for authentication
// This is the counterpart to the private key
// Automatically generated if ssh_public_key variable was empty
output "ssh_public_key" {
  description = "SSH public key used for authentication"
  value       = var.ssh_public_key == "" ? tls_private_key.main[0].public_key_openssh : var.ssh_public_key
}

// ---------------------------------------------------------------------------
// Access Information
// ---------------------------------------------------------------------------
// Convenient connection strings and URLs

// Full URL to access the Flask application
// Paste this into a web browser to access the app
// Example: http://20.42.115.78:5000
output "access_url" {
  description = "URL to access the application"
  value       = "http://${azurerm_public_ip.main.ip_address}:${var.app_service_port}"
}

// SSH command to connect to the VM
// Copy and paste this command to SSH into the VM
// Example: ssh azureuser@20.42.115.78
output "ssh_connection" {
  description = "SSH connection string to access the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

// ---------------------------------------------------------------------------
// Deployment Summary
// ---------------------------------------------------------------------------
// Consolidated view of deployment information

// Complete deployment summary as a structured object
// Contains all essential information in one output
output "deployment_summary" {
  description = "Summary of deployed resources and access information"
  value = {
    // Application access URL
    application_url = "http://${azurerm_public_ip.main.ip_address}:${var.app_service_port}"
    
    // SSH connection command
    ssh_connection = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
    
    // Resource group where resources are deployed
    resource_group = azurerm_resource_group.main.name
    
    // Azure region
    location = azurerm_resource_group.main.location
    
    // VM size
    vm_size = var.vm_size
    
    // Application port
    app_port = var.app_service_port
  }
}
