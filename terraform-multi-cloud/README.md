# Multi-Cloud Terraform Deployment - Project Tracker

Deploy the Project Tracker application to AWS, Azure, or GCP using Terraform.

## Project Structure

```
terraform-multi-cloud/
├── main.tf              # Combined config (all providers)
├── main-aws.tf         # AWS-only config
├── main-azure.tf      # Azure-only config
├── main-gcp.tf        # GCP-only config
├── aws.tfvars          # AWS variables
├── azure.tfvars        # Azure variables
├── gcp.tfvars          # GCP variables
├── deploy.sh           # Bash deployment script
├── deploy.ps1          # PowerShell deployment script
├── modules/
│   ├── aws/            # AWS module
│   ├── azure/          # Azure module
│   └── gcp/            # GCP module
└── README.md
```

## Deployment Script

### Bash (Linux/macOS)
```bash
chmod +x deploy.sh
./deploy.sh aws       # Deploy to AWS
./deploy.sh azure    # Deploy to Azure
./deploy.sh gcp      # Deploy to GCP
./deploy.sh aws plan  # Show AWS plan
./deploy.sh azure destroy # Delete Azure resources
```

### PowerShell (Windows)
```powershell
.\deploy.ps1 aws       # Deploy to AWS
.\deploy.ps1 azure     # Deploy to Azure
.\deploy.ps1 gcp      # Deploy to GCP
.\deploy.ps1 aws plan  # Show AWS plan
```

### Available Commands

| Command | Description |
|---------|-------------|
| `./deploy.sh aws` | Deploy to AWS |
| `./deploy.sh azure` | Deploy to Azure |
| `./deploy.sh gcp` | Deploy to GCP |
| `./deploy.sh <cloud> plan` | Show deployment plan |
| `./deploy.sh <cloud> destroy` | Delete resources |
| `./deploy.sh <cloud> output` | Show outputs |

## Prerequisites

### Terraform
- [Terraform](https://www.terraform.io/downloads) >= 1.0

### AWS
- AWS CLI configured: `aws configure`

### Azure
- Azure CLI: `az login`

### GCP
- Google Cloud SDK: `gcloud auth application-default login`

## Quick Start

### 1. Authenticate
```bash
# AWS
aws configure

# Azure
az login

# GCP
gcloud auth application-default login
```

### 2. Deploy
```bash
./deploy.sh azure    # Deploy to Azure
```

## Configuration

### AWS Variables (`aws.tfvars`)

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | us-east-1 | AWS region |
| `aws_instance_type` | t3.micro | EC2 instance type |

### Azure Variables (`azure.tfvars`)

| Variable | Default | Description |
|----------|---------|-------------|
| `azure_location` | canadacentral | Azure region |
| `azure_vm_size` | Standard_D2s_v3 | VM size |

### GCP Variables (`gcp.tfvars`)

| Variable | Default | Description |
|----------|---------|-------------|
| `gcp_project_id` | (required) | GCP project ID |
| `gcp_region` | us-central1 | GCP region |
| `gcp_machine_type` | e2-micro | Machine type |

## Accessing the Application

```
http://<public-ip>:5000
```

## Cleanup

```bash
./deploy.sh aws destroy   # Delete AWS resources
./deploy.sh azure destroy # Delete Azure resources
./deploy.sh gcp destroy  # Delete GCP resources
```

## Important Notes

1. **Flask Host Binding:** Ensure `app.py` uses `host='0.0.0.0'`

2. **Security:** Restrict CIDR for production:
   ```hcl
   ssh_cidr = "203.0.113.0/32"  # Your IP
   app_cidr = "0.0.0.0/0"
   ```

3. **GCP Project:** Update `gcp_project_id` in `gcp.tfvars`
