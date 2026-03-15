# Azure IaC - Project Tracker Deployment

This project contains Infrastructure as Code (IaC) using Azure Bicep to deploy a Flask-based Project Tracker application on an Azure Virtual Machine with a public Load Balancer.

## Architecture

```
Internet
    |
    | (port 80)
    v
+------------------+
|  Load Balancer  |  <-- project-tracker-lb
|  (Public IP)    |
+--------+---------+
         |
         | (port 5000)
         v
+------------------+
| Virtual Machine  |  <-- project-tracker-vm (Ubuntu 22.04)
| Standard_B2s     |      2 vCPU, 4GB RAM
+--------+---------+
         |
         v
    Flask App (port 5000)
    /opt/project-tracker
```

## Resources Deployed

| Resource | Name | Description |
|----------|------|-------------|
| Virtual Machine | `project-tracker-vm` | 2 vCPU, 4GB RAM, Ubuntu 22.04 LTS |
| Load Balancer | `project-tracker-lb` | Basic SKU, public |
| Public IP | `project-tracker-lb-pip` | Dynamic IP |
| Virtual Network | `project-tracker-vnet` | 10.0.0.0/16 |
| Subnet | `default` | 10.0.0.0/24 |
| NSG | `project-tracker-vm-nsg` | Allows SSH (22), HTTP (5000) |

---

## Prerequisites

### 1. Install Azure CLI

**Windows (PowerShell):**
```powershell
winget install Microsoft.AzureCLI
```

**macOS:**
```bash
brew install azure-cli
```

**Linux:**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### 2. Login to Azure

```bash
az login
```

### 3. Set Subscription (if needed)

```bash
az account set --subscription "Your-Subscription-Name"
```

---

## Step-by-Step Deployment

### Step 1: Update Parameters

Edit `parameters.json` and replace the placeholder password:

```json
{
  "parameters": {
    "adminPassword": {
      "value": "YourSecurePassword123!"
    }
  }
}
```

### Step 2: Run Deployment Script

**Windows (PowerShell):**
```powershell
.\deploy.ps1
```

**Linux/macOS (Bash):**
```bash
chmod +x deploy.sh
./deploy.sh
```

### Step 3: Note the Public IP

After deployment completes, the script will display:
```
Access the application at: http://<public-ip>
```

---

## Manual Deployment (Alternative)

If you prefer to run commands manually:

```bash
# Variables
RESOURCE_GROUP="project-tracker-rg"
LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Deploy template
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters @parameters.json

# Get public IP
az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name project-tracker-lb-pip \
  --query ipAddress \
  --output tsv
```

---

## Accessing the Application

After deployment, open your browser:

```
http://40.xxx.xxx.xxx
```

Replace with the actual public IP address shown in the deployment output.

---

## Troubleshooting

### Check VM Status
```bash
az vm show -g project-tracker-rg -n project-tracker-vm
```

### View Application Logs
```bash
az vm execute-command \
  -g project-tracker-rg \
  -n project-tracker-vm \
  --command-id RunShellScript \
  --script "systemctl status project-tracker"
```

### Connect via SSH
```bash
ssh azureuser@<public-ip>
```

### Restart Application
```bash
az vm execute-command \
  -g project-tracker-rg \
  -n project-tracker-vm \
  --command-id RunShellScript \
  --script "systemctl restart project-tracker"
```

---

## Cleaning Up

To delete all resources:

```bash
az group delete --name project-tracker-rg --yes
```

---

## Customization

### Change VM Size
Edit `main.bicep` and modify:
```bicep
var vmSize = 'Standard_B2s'  // Change to desired size
```

### Change Location
Edit `deploy.ps1` or `deploy.sh`:
```powershell
$Location = "westus2"  # Change to desired region
```

### Change Load Balancer Prefix
Edit `parameters.json`:
```json
{
  "loadBalancerPrefix": {
    "value": "my-app"
  }
}
```

This will create resources with prefix `my-app` instead of `project-tracker`.

---

## Application Details

- **Source Code**: https://github.com/damarc-admin/project-tracker/tree/onboard
- **Framework**: Flask
- **Port**: 5000 (internal), 80 (external via LB)
- **Data Storage**: CSV files (projects.csv, tasks.csv, users.csv, audit.csv)
