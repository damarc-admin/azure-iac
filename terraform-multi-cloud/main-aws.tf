// =============================================================================
// AWS-Only Terraform Configuration - Project Tracker
// =============================================================================
// AWS-specific Terraform configuration for deploying the Project Tracker
// Flask application to Amazon EC2 instances.
//
// This configuration deploys:
//   - VPC with Internet Gateway
//   - Public Subnet
//   - Security Group
//   - Elastic IP
//   - EC2 Instance
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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

// Generates a unique ID for resource naming
resource "random_id" "main" {
  byte_length = 4
  prefix      = "pt-"
}

// Main AWS deployment module
module "aws_deployment" {
  source = "./modules/aws"

  // Resource naming
  prefix    = var.prefix
  region    = var.aws_region
  random_id = random_id.main.hex

  // Instance settings
  instance_type = var.aws_instance_type

  // Application settings
  app_port = var.app_port

  // Security settings
  ssh_cidr = var.ssh_cidr
  app_cidr = var.app_cidr

  // Deployment metadata (passed from deploy script)
  deployed_by   = var.deployed_by
  deployed_date = var.deployed_date
}

// =============================================================================
// Outputs
// =============================================================================

output "deployment_summary" {
  value = {
    cloud           = "AWS"
    public_ip       = module.aws_deployment.public_ip
    instance_id     = module.aws_deployment.instance_id
    security_group  = module.aws_deployment.security_group_id
    vpc_id          = module.aws_deployment.vpc_id
    app_url         = module.aws_deployment.app_url
  }
}

// =============================================================================
// Variables
// =============================================================================

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "project-tracker"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ca-central-1"
}

variable "aws_instance_type" {
  description = "EC2 instance type (e.g., t2.medium)"
  type        = string
  default     = "t2.medium"
}

variable "app_port" {
  description = "Application port (Flask default is 5000)"
  type        = string
  default     = "5000"
}

variable "ssh_cidr" {
  description = "CIDR block for SSH access (0.0.0.0/0 for anywhere)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_cidr" {
  description = "CIDR block for application access (0.0.0.0/0 for anywhere)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "deployed_by" {
  description = "Username of the person deploying (set by deploy script)"
  type        = string
  default     = "unknown"
}

variable "deployed_date" {
  description = "Date of deployment in YYYY-MM-DD format (set by deploy script)"
  type        = string
  default     = "unknown"
}
