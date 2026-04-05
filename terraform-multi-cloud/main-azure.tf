// =============================================================================
// Azure-Only Terraform Configuration - Project Tracker
// =============================================================================

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

provider "azurerm" {
  features {}
}

resource "random_id" "main" {
  byte_length = 4
  prefix      = "pt-"
}

module "azure_deployment" {
  source = "./modules/azure"

  prefix      = var.prefix
  location    = var.azure_location
  vm_size     = var.azure_vm_size
  app_port    = var.app_port
  ssh_cidr    = var.ssh_cidr
  app_cidr    = var.app_cidr
  random_id   = random_id.main.hex
}

output "deployment_summary" {
  value = {
    cloud         = "Azure"
    public_ip    = module.azure_deployment.public_ip
    vm_name      = module.azure_deployment.vm_name
    resource_group = module.azure_deployment.resource_group
    url          = "http://${module.azure_deployment.public_ip}:${var.app_port}"
  }
}

variable "prefix" {
  default = "project-tracker"
}

variable "azure_location" {
  default = "canadacentral"
}

variable "azure_vm_size" {
  default = "Standard_D2s_v3"
}

variable "app_port" {
  default = "5000"
}

variable "ssh_cidr" {
  default = "0.0.0.0/0"
}

variable "app_cidr" {
  default = "0.0.0.0/0"
}
