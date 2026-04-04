# Azure Bicep - Project Tracker VM Deployment

This directory contains Azure Bicep templates to deploy the Project Tracker application on an Azure Virtual Machine with public IP access.

## Files

| File | Description |
|------|-------------|
| `main.bicep` | Main Bicep template with all Azure resources |
| `parameters.json` | Deployment parameters |
| `deploy.sh` | Bash deployment script |
| `deploy.ps1` | PowerShell deployment script |

## Prerequisites

1. **Azure CLI** installed
   ```bash
   # Windows (PowerShell)
   winget install Microsoft.AzureCLI

   # macOS
   brew install azure-cli

   # Linux
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

2. **Login to Azure**
   ```bash
   az login
   ```

## Deployment

### Step 1: Configure Parameters

Edit `parameters.json` and set your password:

```json
{
  "parameters": {
    "adminPassword": {
      "value": "YourSecurePassword123!"
    }
  }
}
```

### Step 2: Deploy

**Linux/macOS:**
```bash
chmod +x deploy.sh
./deploy.sh
```

**Windows (PowerShell):**
```powershell
.\deploy.ps1
```

### Step 3: Access the Application

After deployment, access at:
```
http://<public-ip>:5000
```

## Cleanup

```bash
./deploy.sh --cleanup
```

## Architecture

```
Internet (port 5000)
       |
       ▼
┌─────────────────┐
│   Public IP     │  Standard SKU, Static
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Virtual Machine │  Ubuntu 22.04 LTS
│ Standard_D2s_v3 │  2 vCPU, 8GB RAM
└────────┬────────┘
         │
         ▼
   Flask App (port 5000)
   /opt/project-tracker
```

## Resources Created

| Resource | Description |
|----------|-------------|
| Virtual Network | `project-tracker-vnet` (10.0.0.0/16) |
| Subnet | `default` (10.0.0.0/24) |
| NSG | `project-tracker-vm-nsg` |
| Public IP | `project-tracker-pip` (Standard SKU, Static) |
| Network Interface | `project-tracker-vm-nic` |
| Virtual Machine | `project-tracker-vm` (Ubuntu 22.04) |
| Custom Script Extension | Installs Flask app |

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Location | canadacentral | Azure region |
| VM Size | Standard_D2s_v3 | 2 vCPU, 8GB RAM |
| App Port | 5000 | Flask application port |
| Prefix | project-tracker | Resource name prefix |

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

### Check NSG Rules
```bash
az network nsg rule list -g project-tracker-rg --nsg-name project-tracker-vm-nsg -o table
```

### Verify NSG Attachment
```bash
az network nic show -g project-tracker-rg -n project-tracker-vm-nic --query "networkSecurityGroup"
```

### Get Public IP
```bash
az network public-ip show -g project-tracker-rg -n project-tracker-pip --query ipAddress
```

## Important Notes

1. **Flask Host Binding:** Ensure `app.py` uses `host='0.0.0.0'`:
   ```python
   app.run(host='0.0.0.0', port=5000)
   ```

2. **Standard SKU Public IP:** Requires NSG attachment to NIC.

3. **NSG Rules:** Must allow port 5000 from Internet.
