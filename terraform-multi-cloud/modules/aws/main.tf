// =============================================================================
// AWS Module - Virtual Machine Deployment
// =============================================================================
// Deploys a complete AWS infrastructure for the Project Tracker Flask app:
//   - Virtual Private Cloud (VPC)
//   - Internet Gateway
//   - Subnet with public IP mapping
//   - Route Table
//   - Security Group
//   - Elastic IP Address
//   - Network Interface
//   - EC2 Instance (Ubuntu 22.04)
//
// All resources are tagged with deployment metadata for tracking and auditing.
// =============================================================================

// ---------------------------------------------------------------------------
// Variables (module inputs)
// ---------------------------------------------------------------------------

variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (e.g., t2.medium)"
  type        = string
}

variable "app_port" {
  description = "Application port (Flask default is 5000)"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR block for SSH access (0.0.0.0/0 for anywhere)"
  type        = string
}

variable "app_cidr" {
  description = "CIDR block for application access (0.0.0.0/0 for anywhere)"
  type        = string
}

variable "random_id" {
  description = "Unique random ID for resource naming"
  type        = string
}

variable "deployed_by" {
  description = "Username of the person deploying"
  type        = string
  default     = "unknown"
}

variable "deployed_date" {
  description = "Date of deployment (YYYY-MM-DD)"
  type        = string
  default     = "unknown"
}

// ---------------------------------------------------------------------------
// Common Tags
// ---------------------------------------------------------------------------
// Applied to all resources for consistent tagging across AWS services.

locals {
  common_tags = {
    Name         = "${var.prefix}-${var.random_id}"
    Environment  = "Production"
    ManagedBy    = "Terraform"
    DeployedBy   = var.deployed_by
    DeployedDate = var.deployed_date
  }
}

// ---------------------------------------------------------------------------
// Virtual Private Cloud (VPC)
// ---------------------------------------------------------------------------
// Isolated virtual network for the deployment.
// DNS hostnames and support are enabled for the VPC.

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// Internet Gateway
// ---------------------------------------------------------------------------
// Enables connectivity between the VPC and the internet.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// Subnet
// ---------------------------------------------------------------------------
// Availability zone subnet with public IP auto-assignment.
// Instances launched here get public IPs for internet access.

resource "aws_subnet" "main" {
  vpc_id                   = aws_vpc.main.id
  cidr_block               = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// Route Table
// ---------------------------------------------------------------------------
// Routes traffic through the Internet Gateway for 0.0.0.0/0.

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = local.common_tags
}

// Associate route table with subnet
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

// ---------------------------------------------------------------------------
// Security Group
// ---------------------------------------------------------------------------
// Controls inbound and outbound traffic for the EC2 instance.
// Rules:
//   - SSH (port 22): From specified CIDR
//   - HTTP (app port): From specified CIDR
//   - All outbound: Allowed

resource "aws_security_group" "main" {
  name        = "${var.prefix}-sg-${var.random_id}"
  description = "Security group for Project Tracker VM"
  vpc_id      = aws_vpc.main.id

  // SSH Access
  ingress {
    cidr_blocks = [var.ssh_cidr]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "SSH access"
  }

  // HTTP Access
  ingress {
    cidr_blocks = [var.app_cidr]
    from_port   = tonumber(var.app_port)
    to_port     = tonumber(var.app_port)
    protocol    = "tcp"
    description = "HTTP access"
  }

  // Allow all outbound traffic
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    description = "Allow all outbound"
  }

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// Network Interface
// ---------------------------------------------------------------------------
// Elastic network interface attached to the EC2 instance.
// Uses a fixed private IP within the subnet.

resource "aws_network_interface" "main" {
  subnet_id   = aws_subnet.main.id
  private_ips = ["10.0.1.10"]
  security_groups = [aws_security_group.main.id]

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// Elastic IP Address
// ---------------------------------------------------------------------------
// Static public IP address associated with the network interface.
// Persists even if the instance is stopped/started.

resource "aws_eip" "main" {
  domain = "vpc"

  tags = local.common_tags
}

// Associate EIP with the network interface
resource "aws_eip_association" "main" {
  network_interface_id = aws_network_interface.main.id
  allocation_id        = aws_eip.main.id
}

// ---------------------------------------------------------------------------
// EC2 Instance
// ---------------------------------------------------------------------------
// Ubuntu 22.04 LTS instance with Flask app deployment.
// User data script handles all application setup.

resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.main.id

  // Attach pre-configured network interface
  network_interface {
    network_interface_id = aws_network_interface.main.id
    device_index         = 0
  }

  // User data script runs on first boot
  user_data = <<-EOF
#!/bin/bash
set -e

# Update packages and install dependencies
apt-get update
apt-get install -y python3 git curl

# Install pip
curl -sS https://bootstrap.pypa.io/get-pip.py | python3

# Clone Project Tracker application
cd /opt
git clone https://github.com/damarc-admin/project-tracker.git --branch onboard --single-branch project-tracker

# Install dependencies
cd /opt/project-tracker
pip3 install --break-system-packages --ignore-installed blinker -r requirements.txt

# Create systemd service
cat > /etc/systemd/system/project-tracker.service << 'SERVICEEOF'
[Unit]
Description=Project Tracker Flask Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/project-tracker
ExecStart=/usr/bin/python3 /opt/project-tracker/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Enable and start service
systemctl daemon-reload
systemctl enable project-tracker
systemctl start project-tracker
EOF

  tags = local.common_tags
}

// ---------------------------------------------------------------------------
// Data Sources
// ---------------------------------------------------------------------------
// Find the latest Ubuntu 22.04 LTS AMI from Canonical

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  // Canonical's AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output "public_ip" {
  description = "Public IP address for accessing the application"
  value       = aws_eip.main.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.main.private_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.main.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "app_url" {
  description = "URL to access the deployed application"
  value       = "http://${aws_eip.main.public_ip}:${var.app_port}"
}
