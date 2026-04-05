// =============================================================================
// Multi-Cloud Terraform Configuration - Project Tracker
// =============================================================================
// Deploys the Project Tracker application to AWS, Azure, and GCP
// 
// Usage:
//   terraform init
//   terraform plan -var-file=aws.tfvars
//   terraform apply -var-file=aws.tfvars
// =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

// =============================================================================
// AWS Provider Configuration
// =============================================================================
provider "aws" {
  region = var.enable_aws ? var.aws_region : "us-east-1"
  alias  = "aws"
}

// =============================================================================
// Azure Provider Configuration
// =============================================================================
provider "azurerm" {
  features {}
  alias = "azure"
}

// =============================================================================
// GCP Provider Configuration
// =============================================================================
provider "google" {
  project = var.enable_gcp ? var.gcp_project_id : "placeholder-project"
  region  = var.gcp_region
  alias   = "gcp"
}

// =============================================================================
// Random ID for Unique Naming
// =============================================================================
resource "random_id" "main" {
  byte_length = 4
  prefix      = "pt-"
}

// =============================================================================
// AWS Resources
// =============================================================================
module "aws_deployment" {
  source = "./modules/aws"

  providers = {
    aws = aws.aws
  }

  count = var.enable_aws ? 1 : 0

  prefix        = var.prefix
  instance_type = var.aws_instance_type
  region        = var.aws_region
  app_port      = var.app_port
  ssh_cidr      = var.ssh_cidr
  app_cidr      = var.app_cidr
  random_id     = random_id.main.hex
}

// =============================================================================
// Azure Resources
// =============================================================================
module "azure_deployment" {
  source = "./modules/azure"

  providers = {
    azurerm = azurerm.azure
  }

  count = var.enable_azure ? 1 : 0

  prefix      = var.prefix
  location    = var.azure_location
  vm_size     = var.azure_vm_size
  app_port    = var.app_port
  ssh_cidr    = var.ssh_cidr
  app_cidr    = var.app_cidr
  random_id   = random_id.main.hex
}

// =============================================================================
// GCP Resources
// =============================================================================
module "gcp_deployment" {
  source = "./modules/gcp"

  providers = {
    google = google.gcp
  }

  count = var.enable_gcp ? 1 : 0

  prefix       = var.prefix
  region       = var.gcp_region
  machine_type = var.gcp_machine_type
  app_port     = var.app_port
  ssh_cidr     = var.ssh_cidr
  app_cidr     = var.app_cidr
  random_id    = random_id.main.hex
}

// =============================================================================
// Deployment Summary
// =============================================================================
output "deployment_summary" {
  description = "Summary of deployments"

  value = {
    aws = var.enable_aws ? {
      enabled   = true
      public_ip = module.aws_deployment[0].public_ip
      url       = "http://${module.aws_deployment[0].public_ip}:${var.app_port}"
    } : {
      enabled   = false
      public_ip = null
      url       = null
    }

    azure = var.enable_azure ? {
      enabled   = true
      public_ip = module.azure_deployment[0].public_ip
      url       = "http://${module.azure_deployment[0].public_ip}:${var.app_port}"
    } : {
      enabled   = false
      public_ip = null
      url       = null
    }

    gcp = var.enable_gcp ? {
      enabled   = true
      public_ip = module.gcp_deployment[0].public_ip
      url       = "http://${module.gcp_deployment[0].public_ip}:${var.app_port}"
    } : {
      enabled   = false
      public_ip = null
      url       = null
    }
  }
}
