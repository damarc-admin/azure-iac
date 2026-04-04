// =============================================================================
// Terraform Variables - Multi-Cloud Project Tracker Deployment
// =============================================================================

// ---------------------------------------------------------------------------
// Deployment Control
// ---------------------------------------------------------------------------
// Enable/disable deployments to specific clouds

variable "enable_aws" {
  description = "Enable deployment to AWS"
  type        = bool
  default     = false
}

variable "enable_azure" {
  description = "Enable deployment to Azure"
  type        = bool
  default     = false
}

variable "enable_gcp" {
  description = "Enable deployment to GCP"
  type        = bool
  default     = false
}

// ---------------------------------------------------------------------------
// Common Settings
// ---------------------------------------------------------------------------

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "project-tracker"
}

variable "app_port" {
  description = "Port on which the Flask application runs"
  type        = string
  default     = "5000"
}

variable "ssh_cidr" {
  description = "CIDR block for SSH access (use '0.0.0.0/0' for anywhere)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_cidr" {
  description = "CIDR block for application access (use '0.0.0.0/0' for anywhere)"
  type        = string
  default     = "0.0.0.0/0"
}

// ---------------------------------------------------------------------------
// AWS Configuration
// ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "aws_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

// ---------------------------------------------------------------------------
// Azure Configuration
// ---------------------------------------------------------------------------

variable "azure_location" {
  description = "Azure region for deployment"
  type        = string
  default     = "canadacentral"
}

variable "azure_vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_D2s_v3"
}

// ---------------------------------------------------------------------------
// GCP Configuration
// ---------------------------------------------------------------------------

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
  default     = "my-gcp-project"
}

variable "gcp_region" {
  description = "GCP region for deployment"
  type        = string
  default     = "us-central1"
}

variable "gcp_machine_type" {
  description = "GCP machine type"
  type        = string
  default     = "e2-micro"
}
