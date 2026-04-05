// =============================================================================
// AWS Variables - Project Tracker Deployment
// =============================================================================
// Enable AWS deployment and configure AWS-specific settings
// =============================================================================

// Enable AWS deployment
enable_aws   = true
enable_azure = false
enable_gcp   = false

// AWS Configuration
aws_region      = "us-east-1"
aws_instance_type = "t3.micro"

// Azure Configuration (required for provider init)
azure_location = "canadacentral"
azure_vm_size = "Standard_D2s_v3"

// GCP Configuration (required for provider init)
gcp_project_id  = "dummy-project"
gcp_region      = "us-central1"
gcp_machine_type = "e2-micro"

// Common Settings
prefix   = "project-tracker"
app_port = "5000"

// Security
ssh_cidr = "0.0.0.0/0"
app_cidr = "0.0.0.0/0"
