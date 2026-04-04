// =============================================================================
// AWS Module - Virtual Machine Deployment
// =============================================================================

// ---------------------------------------------------------------------------
// Variables (module inputs)
// ---------------------------------------------------------------------------

variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "app_port" {
  description = "Application port"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR for SSH access"
  type        = string
}

variable "app_cidr" {
  description = "CIDR for app access"
  type        = string
}

variable "random_id" {
  description = "Random ID for unique naming"
  type        = string
}

// ---------------------------------------------------------------------------
// Security Group
// ---------------------------------------------------------------------------

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
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    description = "HTTP access"
  }

  // Outbound all traffic
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  tags = {
    Name        = "${var.prefix}-sg-${var.random_id}"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

// ---------------------------------------------------------------------------
// VPC
// ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.prefix}-vpc-${var.random_id}"
    Environment = "Production"
  }
}

// ---------------------------------------------------------------------------
// Internet Gateway
// ---------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.prefix}-igw-${var.random_id}"
  }
}

// ---------------------------------------------------------------------------
// Subnet
// ---------------------------------------------------------------------------

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-${var.random_id}"
  }
}

// ---------------------------------------------------------------------------
// Route Table
// ---------------------------------------------------------------------------

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.prefix}-rt-${var.random_id}"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

// ---------------------------------------------------------------------------
// Network Interface
// ---------------------------------------------------------------------------

resource "aws_network_interface" "main" {
  subnet_id   = aws_subnet.main.id
  private_ips = ["10.0.1.10"]

  tags = {
    Name = "${var.prefix}-nic-${var.random_id}"
  }
}

// ---------------------------------------------------------------------------
// Elastic IP
// ---------------------------------------------------------------------------

resource "aws_eip" "main" {
  domain = "vpc"

  tags = {
    Name = "${var.prefix}-eip-${var.random_id}"
  }
}

resource "aws_eip_association" "main" {
  network_interface_id = aws_network_interface.main.id
  allocation_id        = aws_eip.main.id
}

// ---------------------------------------------------------------------------
// EC2 Instance
// ---------------------------------------------------------------------------

resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.main.id

  network_interface {
    network_interface_id = aws_network_interface.main.id
    device_index        = 0
  }

  user_data = <<-EOF
#!/bin/bash
set -e

apt-get update
apt-get install -y python3 git curl

curl -sS https://bootstrap.pypa.io/get-pip.py | python3

cd /opt
git clone https://github.com/damarc-admin/project-tracker.git --branch onboard --single-branch project-tracker

cd /opt/project-tracker
pip3 install --break-system-packages --ignore-installed blinker -r requirements.txt

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

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable project-tracker
systemctl start project-tracker
EOF

  tags = {
    Name        = "${var.prefix}-vm-${var.random_id}"
    Environment = "Production"
  }
}

// ---------------------------------------------------------------------------
// Data Sources
// ---------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  // Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output "public_ip" {
  description = "Public IP address of the instance"
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
