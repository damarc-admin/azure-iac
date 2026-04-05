// =============================================================================
// GCP-Only Terraform Configuration - Project Tracker
// =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
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

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

resource "random_id" "main" {
  byte_length = 4
  prefix      = "pt-"
}

module "gcp_deployment" {
  source = "./modules/gcp"

  prefix    = var.prefix
  region    = var.gcp_region
  machine_type = var.gcp_machine_type
  app_port  = var.app_port
  ssh_cidr  = var.ssh_cidr
  app_cidr  = var.app_cidr
  random_id = random_id.main.hex
}

output "deployment_summary" {
  value = {
    cloud       = "GCP"
    public_ip   = module.gcp_deployment.public_ip
    vm_name     = module.gcp_deployment.instance_name
    zone        = module.gcp_deployment.zone
    url         = "http://${module.gcp_deployment.public_ip}:${var.app_port}"
  }
}

variable "prefix" {
  default = "project-tracker"
}

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  default = "northamerica-northeast1"
}

variable "gcp_machine_type" {
  default = "e2-standard-2"
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
