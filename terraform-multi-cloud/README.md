# Multi-Cloud Terraform Deployment - Project Tracker

Deploy the Project Tracker Flask application to AWS, Azure, or GCP using Terraform with automatic cleanup on failure and deployment tracking.

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEPLOYMENT WORKFLOW                                  │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────────┐
    │   User       │
    │  executes    │
    │  deploy.sh   │
    └──────┬───────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        1. PREREQUISITES CHECK                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                       │
│  │   Terraform │  │   Cloud CLI  │  │   Creds     │                       │
│  │   Installed  │  │   Installed  │  │  Configured │                       │
│  └─────────────┘  └─────────────┘  └─────────────┘                       │
└─────────────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        2. CONFIGURATION SETUP                               │
│                                                                              │
│  • Identify cloud provider (aws/azure/gcp)                                   │
│  • Remove other cloud config files (avoids provider conflicts)               │
│  • Load cloud-specific .tf and .tfvars files                                │
│                                                                              │
│  Files: main-<cloud>.tf + <cloud>.tfvars                                    │
└─────────────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        3. TERRAFORM INIT                                     │
│                                                                              │
│  • Initialize provider plugins (hashicorp/azurerm, etc.)                     │
│  • Download required modules                                                  │
│  • Configure state storage                                                    │
└─────────────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        4. TERRAFORM PLAN                                     │
│                                                                              │
│  • Generate execution plan                                                   │
│  • Apply deployment metadata:                                                │
│    - deployed_by: <username>                                                │
│    - deployed_date: <YYYY-MM-DD>                                             │
│  • Preview resources to be created                                           │
└─────────────────────────────────────────────────────────────────────────────┘
           │
           ▼
    ┌──────┴───────┐
    │   Apply?      │
    └──────┬───────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        5. TERRAFORM APPLY                                   │
│                                                                              │
│  For Azure:           For AWS:            For GCP:                           │
│  ┌──────────────┐    ┌──────────────┐   ┌──────────────┐                   │
│  │ Resource     │    │ VPC          │   │ Firewall     │                   │
│  │ Group        │    │ Subnet       │   │ Rules        │                   │
│  ├──────────────┤    ├──────────────┤   ├──────────────┤                   │
│  │ Virtual      │    │ Security     │   │ Static IP    │                   │
│  │ Network      │    │ Group        │   ├──────────────┤                   │
│  ├──────────────┤    ├──────────────┤   │ Compute      │                   │
│  │ Subnet       │    │ Elastic IP   │   │ Instance     │                   │
│  ├──────────────┤    ├──────────────┤   └──────────────┘                   │
│  │ NSG          │    ├──────────────┤                                            │
│  ├──────────────┤    │ EC2          │                                            │
│  │ Public IP    │    │ Instance     │                                            │
│  ├──────────────┤    └──────────────┘                                            │
│  │ NIC          │                                                                 │
│  ├──────────────┤                                                                 │
│  │ Linux VM     │                                                                 │
│  ├──────────────┤                                                                 │
│  │ Custom       │                                                                 │
│  │ Script Ext   │                                                                 │
│  └──────────────┘                                                                 │
│                                                                              │
│  All resources tagged with:                                                  │
│  • Environment=Production                                                    │
│  • ManagedBy=Terraform                                                        │
│  • DeployedBy=<username>                                                      │
│  • DeployedDate=<YYYY-MM-DD>                                                  │
└─────────────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        6. APP DEPLOYMENT (VM Startup)                         │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    Custom Script / User Data                          │    │
│  │                                                                       │    │
│  │  1. Update packages (apt-get update)                                  │    │
│  │  2. Install: python3, git, curl                                       │    │
│  │  3. Install pip                                                       │    │
│  │  4. Clone app from GitHub (branch: onboard)                          │    │
│  │  5. Install Python dependencies (pip install -r requirements.txt)    │    │
│  │  6. Create systemd service (project-tracker.service)                   │    │
│  │  7. Enable and start service                                          │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SUCCESS                                            │
│                                                                              │
│  Output: http://<public-ip>:5000                                             │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ Resources are deployed and running                                    │    │
│  │ Flask app listening on 0.0.0.0:5000                                  │    │
│  │ Accessible from browser at http://<public-ip>:5000                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────┐
                    │         FAILURE HANDLING            │
                    └─────────────────────────────────────┘
                                   │
                    If terraform apply fails ────────────► Automatic Cleanup
                                   │
                    ┌──────────────────────────────────────────────┐
                    │              terraform destroy              │
                    │         (removes all created resources)      │
                    └──────────────────────────────────────────────┘
```

## Project Structure

```
terraform-multi-cloud/
├── main.tf              # Combined config (all providers) - reference only
├── main-aws.tf         # AWS-only configuration
├── main-azure.tf       # Azure-only configuration
├── main-gcp.tf         # GCP-only configuration
├── aws.tfvars          # AWS variable values
├── azure.tfvars        # Azure variable values
├── gcp.tfvars          # GCP variable values (update gcp_project_id!)
├── deploy.sh           # Bash deployment script (Linux/macOS)
├── deploy.ps1          # PowerShell deployment script (Windows)
├── modules/
│   ├── aws/
│   │   └── main.tf     # AWS: VPC, EC2, Security Groups
│   ├── azure/
│   │   └── main.tf     # Azure: VNet, VM, NSG, Extensions
│   └── gcp/
│       └── main.tf     # GCP: Firewall, Compute Engine
└── README.md
```

## Deployment Script

### Bash (Linux/macOS/WSL)

```bash
chmod +x deploy.sh

# Deploy to a specific cloud
./deploy.sh aws         # Deploy to AWS
./deploy.sh azure       # Deploy to Azure
./deploy.sh gcp         # Deploy to GCP

# Other commands
./deploy.sh azure plan     # Preview Azure deployment
./deploy.sh azure destroy  # Delete Azure resources
./deploy.sh azure output   # Show Azure outputs
```

### PowerShell (Windows)

```powershell
# Deploy to a specific cloud
.\deploy.ps1 -Cloud aws         # Deploy to AWS
.\deploy.ps1 -Cloud azure       # Deploy to Azure
.\deploy.ps1 -Cloud gcp         # Deploy to GCP

# Other commands
.\deploy.ps1 -Cloud azure -Command plan     # Preview Azure deployment
.\deploy.ps1 -Cloud azure -Command destroy  # Delete Azure resources
.\deploy.ps1 -Cloud azure -Command output   # Show Azure outputs
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `deploy.sh <cloud>` | Deploy to cloud (applies plan) |
| `deploy.sh <cloud> plan` | Preview deployment without applying |
| `deploy.sh <cloud> apply` | Deploy resources (default) |
| `deploy.sh <cloud> destroy` | Delete all resources |
| `deploy.sh <cloud> output` | Show deployment outputs |

## Prerequisites

### Required for All Providers

1. **Terraform** >= 1.0
   - Download from: https://www.terraform.io/downloads

2. **Git** (for cloning the app)

### Cloud-Specific Setup

#### AWS
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Configure credentials
aws configure
```

#### Azure
```powershell
# Install Azure CLI (Windows)
winget install Microsoft.AzureCLI

# Login
az login
```

#### GCP
```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
gcloud init

# Authenticate
gcloud auth application-default login
```

## Configuration

### AWS Variables (`aws.tfvars`)

| Variable | Default | Description |
|----------|---------|-------------|
| `prefix` | project-tracker | Resource name prefix |
| `aws_region` | ca-central-1 | AWS region |
| `aws_instance_type` | t2.medium | EC2 instance type |
| `app_port` | 5000 | Application port |
| `ssh_cidr` | 0.0.0.0/0 | SSH access CIDR |
| `app_cidr` | 0.0.0.0/0 | App access CIDR |

### Azure Variables (`azure.tfvars`)

| Variable | Default | Description |
|----------|---------|-------------|
| `prefix` | project-tracker | Resource name prefix |
| `azure_location` | canadacentral | Azure region |
| `azure_vm_size` | Standard_D2s_v3 | VM size |
| `app_port` | 5000 | Application port |
| `ssh_cidr` | 0.0.0.0/0 | SSH access CIDR |
| `app_cidr` | 0.0.0.0/0 | App access CIDR |

### GCP Variables (`gcp.tfvars`)

| Variable | Default | Description |
|----------|---------|-------------|
| `prefix` | project-tracker | Resource name prefix |
| `gcp_project_id` | **REQUIRED** | GCP project ID |
| `gcp_region` | northamerica-northeast1 | GCP region |
| `gcp_machine_type` | e2-standard-2 | Machine type |
| `app_port` | 5000 | Application port |
| `ssh_cidr` | 0.0.0.0/0 | SSH access CIDR |
| `app_cidr` | 0.0.0.0/0 | App access CIDR |

## Deployment Metadata Tags

All resources are automatically tagged with:

| Tag | Source | Example |
|-----|--------|---------|
| `Environment` | Static | Production |
| `ManagedBy` | Static | Terraform |
| `DeployedBy` | User running script | john.doe |
| `DeployedDate` | Date of deployment | 2026-04-05 |

## Failure Handling

The deploy scripts automatically handle deployment failures:

1. **On apply failure:**
   - Script detects non-zero exit code
   - Runs `terraform destroy` to clean up
   - Reports which resources were cleaned up

2. **Manual cleanup:**
   ```bash
   ./deploy.sh <cloud> destroy
   ```

## Accessing the Application

After successful deployment:
```
http://<public-ip>:5000
```

The output will display the exact URL.

## Security Notes

1. **Flask App:** Ensure `app.py` binds to `0.0.0.0` (not `127.0.0.1`)

2. **CIDR Restriction:** For production, restrict access:
   ```hcl
   ssh_cidr = "203.0.113.0/32"  # Your specific IP
   app_cidr = "0.0.0.0/0"       # Public access (or your IP)
   ```

3. **Password:** Change the VM admin password before production use

## Troubleshooting

### Azure: NSG not allowing traffic
- Standard SKU public IPs require NSG attached to NIC (handled automatically)
- Check if port 5000 is open in the NSG rules

### GCP: Firewall rules not working
- Ensure instance tags match firewall target tags
- Check that the static IP is properly attached

### App not responding
- Verify the systemd service is running: `systemctl status project-tracker`
- Check logs: `journalctl -u project-tracker`
- Verify Flask is listening on 0.0.0.0 not 127.0.0.1

## Cleanup

Delete all resources:
```bash
./deploy.sh aws destroy      # Delete AWS resources
./deploy.sh azure destroy    # Delete Azure resources
./deploy.sh gcp destroy      # Delete GCP resources
```
