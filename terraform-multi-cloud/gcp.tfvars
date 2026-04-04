// =============================================================================
// GCP Variables - Project Tracker Deployment
// =============================================================================
// Enable GCP deployment and configure GCP-specific settings
// =============================================================================

// Enable GCP deployment
enable_aws = false
enable_azure = false
enable_gcp = true

// GCP Configuration (UPDATE THESE)
gcp_project_id  = "your-gcp-project-id"
gcp_region      = "us-central1"
gcp_machine_type = "e2-micro"

// Common Settings
prefix   = "project-tracker"
app_port = "5000"

// Security (restrict to your IP for production)
ssh_cidr = "0.0.0.0/0"
app_cidr = "0.0.0.0/0"
