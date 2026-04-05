// =============================================================================
// AWS-Only Terraform Configuration - Project Tracker
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

resource "random_id" "main" {
  byte_length = 4
  prefix      = "pt-"
}

module "aws_deployment" {
  source = "./modules/aws"

  prefix        = var.prefix
  region        = var.aws_region
  instance_type = var.aws_instance_type
  app_port      = var.app_port
  ssh_cidr      = var.ssh_cidr
  app_cidr      = var.app_cidr
  random_id     = random_id.main.hex
}

output "deployment_summary" {
  value = {
    cloud         = "AWS"
    public_ip     = module.aws_deployment.public_ip
    instance_id   = module.aws_deployment.instance_id
    security_group = module.aws_deployment.security_group_id
    url           = "http://${module.aws_deployment.public_ip}:${var.app_port}"
  }
}

variable "prefix" {
  default = "project-tracker"
}

variable "aws_region" {
  default = "ca-central-1"
}

variable "aws_instance_type" {
  default = "t2.medium"
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
