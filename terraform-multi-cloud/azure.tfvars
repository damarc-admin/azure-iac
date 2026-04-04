// =============================================================================
// Azure Variables - Project Tracker Deployment
// =============================================================================
// Enable Azure deployment and configure Azure-specific settings
// =============================================================================

// Enable Azure deployment
enable_aws = false
enable_azure = true
enable_gcp = false

// Azure Configuration
azure_location = "canadacentral"
azure_vm_size  = "Standard_D2s_v3"

// Common Settings
prefix   = "project-tracker"
app_port = "5000"

// Security (restrict to your IP for production)
ssh_cidr = "0.0.0.0/0"
app_cidr = "0.0.0.0/0"
