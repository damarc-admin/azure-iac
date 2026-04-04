# Terraform Deployment - Project Tracker

This directory contains Terraform configuration to deploy the Project Tracker application on Azure Virtual Machine.

## Files

| File | Description |
|------|-------------|
| `main.tf` | Main Terraform configuration |
| `variables.tf` | Input variable definitions |
| `outputs.tf` | Output value definitions |
| `terraform.tfvars.example` | Template for variables |
| `deploy.sh` | Bash deployment script |
| `deploy.ps1` | PowerShell deployment script |

## Prerequisites

1. **Terraform** installed
   ```bash
   # Windows (PowerShell)
   winget install HashiCorp.Terraform

   # macOS
   brew install terraform

   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip -d /usr/local/bin/
   ```

2. **Azure CLI** installed and logged in
   ```bash
   az login
   ```

## Deployment

### 1. Configure Variables

Copy the example file and edit:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your password:
```hcl
admin_password = "YourSecurePassword123!"
```

### 2. Deploy

**Linux/macOS:**
```bash
chmod +x deploy.sh
./deploy.sh
```

**Windows (PowerShell):**
```powershell
.\deploy.ps1
```

## Resources Created

| Resource | Description |
|----------|-------------|
| Resource Group | Container for all resources |
| Virtual Network | `10.0.0.0/16` network |
| Subnet | `10.0.0.0/24` subnet |
| NSG | Security rules for SSH (22) and HTTP (5000) |
| Public IP | Standard SKU, Static |
| Network Interface | Connected to subnet and public IP |
| Virtual Machine | Ubuntu 22.04 LTS, Standard_D2s_v3 |
| Custom Script Extension | Installs and starts Flask app |

## Outputs

After deployment, Terraform outputs:
- `public_ip_address` - Public IP of the VM
- `access_url` - URL to access the application
- `ssh_connection` - SSH connection string

## Accessing the Application

```
http://<public-ip>:5000
```

## Troubleshooting

### Check VM Status
```bash
az vm show -g project-tracker-rg -n project-tracker-vm
```

### View Application Logs
```bash
az vm run-command invoke \
  -g project-tracker-rg \
  -n project-tracker-vm \
  --command-id RunShellScript \
  --script "systemctl status project-tracker"
```

### SSH into VM
```bash
ssh azureuser@<public-ip>
```

## Cleanup

```bash
# Using Terraform
terraform destroy

# Or using Azure CLI
az group delete --name project-tracker-rg --yes
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `location` | canadacentral | Azure region |
| `resource_group_name` | project-tracker-rg | Resource group name |
| `vm_size` | Standard_D2s_v3 | VM size |
| `admin_username` | azureuser | VM admin username |
| `app_service_port` | 5000 | Application port |
