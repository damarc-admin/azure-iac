# Multi-Cloud Terraform Deployment - Project Tracker

Deploy the Project Tracker application to AWS, Azure, and GCP using Terraform.

## Project Structure

```
terraform-multi-cloud/
├── main.tf              # Main configuration (providers, modules)
├── variables.tf         # Variable definitions
├── aws.tfvars          # AWS deployment variables
├── azure.tfvars        # Azure deployment variables
├── gcp.tfvars          # GCP deployment variables
├── deploy.sh           # Bash deployment script
├── deploy.ps1          # PowerShell deployment script
├── modules/
│   ├── aws/            # AWS deployment module
│   ├── azure/          # Azure deployment module
│   └── gcp/            # GCP deployment module
└── README.md
```

## Deployment Script

Use the deployment script to deploy to any cloud provider:

### Bash (Linux/macOS)
```bash
chmod +x deploy.sh
./deploy.sh aws       # Deploy to AWS
./deploy.sh azure    # Deploy to Azure
./deploy.sh gcp       # Deploy to GCP
./deploy.sh all      # Deploy to all clouds
./deploy.sh aws plan  # Show AWS plan
./deploy.sh aws destroy # Delete AWS resources
```

### PowerShell (Windows)
```powershell
.\deploy.ps1 aws       # Deploy to AWS
.\deploy.ps1 azure     # Deploy to Azure
.\deploy.ps1 gcp       # Deploy to GCP
.\deploy.ps1 all       # Deploy to all clouds
.\deploy.ps1 aws plan  # Show AWS plan
.\deploy.ps1 aws destroy # Delete AWS resources
```

### Available Commands

| Command | Description |
|---------|-------------|
| `./deploy.sh aws` | Deploy to AWS |
| `./deploy.sh azure` | Deploy to Azure |
| `./deploy.sh gcp` | Deploy to GCP |
| `./deploy.sh all` | Deploy to all clouds |
| `./deploy.sh <cloud> plan` | Show deployment plan |
| `./deploy.sh <cloud> destroy` | Delete resources |
| `./deploy.sh <cloud> output` | Show outputs |
| `./deploy.sh destroy` | Delete all clouds |
| `./deploy.sh help` | Show help |

## Prerequisites

### All Clouds
- [Terraform](https://www.terraform.io/downloads) >= 1.0

### AWS
- AWS CLI configured (`aws configure`)
- Appropriate IAM permissions

### Azure
- Azure CLI (`az login`)
- Appropriate Azure subscription

### GCP
- Google Cloud SDK (`gcloud init`)
- Application Default Credentials:
  ```bash
  gcloud auth application-default login
  ```

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform-multi-cloud
./deploy.sh aws       # Deploy to AWS

```bash
terraform plan -var-file=aws.tfvars
terraform apply -var-file=aws.tfvars
```

### 3. Deploy to Azure

```bash
terraform plan -var-file=azure.tfvars
terraform apply -var-file=azure.tfvars
```

### 4. Deploy to GCP

```bash
terraform plan -var-file=gcp.tfvars
terraform apply -var-file=gcp.tfvars
```

## Configuration

### Enable Multiple Clouds

Edit the `.tfvars` file to enable multiple providers:

```hcl
enable_aws   = true
enable_azure = true
enable_gcp   = true
```

### Common Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `prefix` | project-tracker | Resource name prefix |
| `app_port` | 5000 | Application port |
| `ssh_cidr` | 0.0.0.0/0 | SSH access CIDR |
| `app_cidr` | 0.0.0.0/0 | App access CIDR |

### AWS Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | us-east-1 | AWS region |
| `aws_instance_type` | t3.micro | EC2 instance type |

### Azure Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `azure_location` | canadacentral | Azure region |
| `azure_vm_size` | Standard_D2s_v3 | VM size |

### GCP Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `gcp_project_id` | (required) | GCP project ID |
| `gcp_region` | us-central1 | GCP region |
| `gcp_machine_type` | e2-micro | Machine type |

## Outputs

After deployment, Terraform will show:

```
deployment_summary = {
  "aws" = {
    "enabled" = true
    "public_ip" = "54.123.45.67"
    "url" = "http://54.123.45.67:5000"
  }
  ...
}
```

## Accessing the Application

```
http://<public-ip>:5000
```

## Cleanup

Destroy resources:

```bash
# AWS
terraform destroy -var-file=aws.tfvars

# Azure
terraform destroy -var-file=azure.tfvars

# GCP
terraform destroy -var-file=gcp.tfvars
```

## Architecture Comparison

### AWS
```
Internet -> Security Group -> EC2 Instance (Ubuntu)
                ↓
          Elastic IP
```

### Azure
```
Internet -> NSG -> Network Interface -> VM (Ubuntu)
                    ↓
              Public IP
```

### GCP
```
Internet -> Firewall -> Compute Engine (Ubuntu)
                     ↓
              Static IP
```

## Important Notes

1. **Flask Host Binding:** Ensure `app.py` uses `host='0.0.0.0'`

2. **Security:** For production, restrict `ssh_cidr` and `app_cidr` to your IP:
   ```hcl
   ssh_cidr = "203.0.113.0/32"  # Your IP
   app_cidr = "0.0.0.0/0"
   ```

3. **GCP Project:** Update `gcp_project_id` in `gcp.tfvars` with your actual project ID

4. **Azure Password:** Update the password in the Azure module (currently placeholder)
