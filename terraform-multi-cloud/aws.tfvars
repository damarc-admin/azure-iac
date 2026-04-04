// =============================================================================
// AWS Variables - Project Tracker Deployment
// =============================================================================
// Enable AWS deployment and configure AWS-specific settings
// =============================================================================

// Enable AWS deployment
enable_aws = true
enable_azure = false
enable_gcp = false

// AWS Configuration
aws_region      = "us-east-1"
aws_instance_type = "t3.micro"

// Common Settings
prefix   = "project-tracker"
app_port = "5000"

// Security (restrict to your IP for production)
ssh_cidr = "0.0.0.0/0"
app_cidr = "0.0.0.0/0"
