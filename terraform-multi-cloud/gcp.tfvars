// =============================================================================
// GCP Variables - Project Tracker Deployment
// =============================================================================
// Enable GCP deployment and configure GCP-specific settings
// =============================================================================

// Enable GCP deployment
enable_aws   = false
enable_azure = false
enable_gcp   = true

// GCP Configuration (UPDATE THIS - REQUIRED)
gcp_project_id  = "your-gcp-project-id"
gcp_region      = "us-central1"
gcp_machine_type = "e2-micro"

// AWS Configuration (placeholder - not used)
aws_region      = "us-east-1"
aws_instance_type = "t3.micro"

// Azure Configuration (placeholder - not used)
azure_location = "canadacentral"
azure_vm_size = "Standard_D2s_v3"

// Common Settings
prefix   = "project-tracker"
app_port = "5000"

// Security
ssh_cidr = "0.0.0.0/0"
app_cidr = "0.0.0.0/0"
