// =============================================================================
// Azure Variables - Project Tracker Deployment
// =============================================================================
// Enable Azure deployment and configure Azure-specific settings
// =============================================================================

// Enable Azure deployment
enable_aws   = false
enable_azure = true
enable_gcp   = false

// Azure Configuration
azure_location = "canadacentral"
azure_vm_size = "Standard_D2s_v3"

// AWS Configuration (required for provider init)
aws_region      = "us-east-1"
aws_instance_type = "t3.micro"

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
