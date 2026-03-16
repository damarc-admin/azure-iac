# Azure IaC - Project Tracker Deployment

This project contains Infrastructure as Code (IaC) using Azure Bicep to deploy a Flask-based Project Tracker application on an Azure Virtual Machine with a public IP.

## Architecture

```
Internet
    |
    | (port 5000)
    v
+------------------+
|  Public IP      |  <-- project-tracker-pip (Standard SKU, Static)
+--------+---------+
         |
         v
+------------------+
| Virtual Machine  |  <-- project-tracker-vm (Ubuntu 22.04)
| Standard_D2s_v3 |      2 vCPU, 8GB RAM
+--------+---------+
         |
         v
    Flask App (port 5000)
    /opt/project-tracker
```

## Azure Resources Explained

### 1. Virtual Network (VNet)
- **What:** A private network in Azure that connects Azure resources to each other and to the internet.
- **Why:** Provides isolated network environment for the VM with customizable IP addressing.
- **In this deployment:** `project-tracker-vnet` with address space `10.0.0.0/16`

### 2. Subnet
- **What:** A logical subdivision of a VNet.
- **Why:** Segments the network and allows NSG rules to be applied.
- **In this deployment:** `default` subnet with `10.0.0.0/24`

### 3. Network Security Group (NSG)
- **What:** Filters network traffic to/from Azure resources using security rules.
- **Why:** Acts as a firewall to control what traffic is allowed in/out of the VM.
- **In this deployment:** 
  - Rule 1: Allow SSH (port 22) from Internet
  - Rule 2: Allow HTTP (port 5000) from Internet
- **Important:** Required to be attached to NIC for Standard SKU public IPs.

### 4. Public IP Address
- **What:** An IP address that is accessible from the internet.
- **Why:** Allows external users to connect to the VM.
- **In this deployment:** Standard SKU, Static IP attached to the NIC
- **Note:** Standard SKU is required for production and when using NSG with public IPs.

### 5. Network Interface (NIC)
- **What:** Connects a VM to a VNet, public IP, and NSG.
- **Why:** The bridge between the VM and network resources.
- **In this deployment:** Connects VM to subnet, public IP, and NSG

### 6. Virtual Machine (VM)
- **What:** An on-demand, scalable computing resource in Azure.
- **Why:** Hosts the Flask application and all its dependencies.
- **In this deployment:** 
  - OS: Ubuntu 22.04 LTS
  - Size: Standard_D2s_v3 (2 vCPU, 8GB RAM)
  - Storage: Standard_LRS (128GB SSD)

### 7. Custom Script Extension
- **What:** An extension that runs custom scripts on a VM after deployment.
- **Why:** Automates application installation and configuration.
- **In this deployment:** Runs bash script to install Python, clone repo, and start Flask app.

---

## Traffic Flow

```
1. User accesses: http://<public-ip>:5000

2. Request hits Public IP (project-tracker-pip)
   - Static IP forwards traffic to attached NIC

3. Network Interface (project-tracker-vm-nic)
   - Receives traffic from Public IP
   - Checks NSG rules (allow port 5000)
   - Forwards to VM's private IP (10.0.0.4)

4. Virtual Machine (project-tracker-vm)
   - Receives request on port 5000
   - Flask application processes request
   - Returns response

5. Response follows reverse path back to user
```

---

## Resource Dependency Flow

```
1. Virtual Network (vnet)
   └── 2. Subnet (requires vnet)
         └── 3. NSG (attached to subnet)
               └── 4. Public IP (standalone)
                     └── 5. NIC (uses vnet subnet, public IP, NSG)
                           └── 6. VM (uses NIC)
                                 └── 7. Custom Script Extension (runs on VM)
```

## Why These Specific Resources?

| Resource | Reason for Use |
|----------|----------------|
| Standard SKU Public IP | Required for NSG attachment; provides static IP |
| Standard_D2s_v3 | 2 vCPU / 8GB RAM - adequate for Flask app |
| Ubuntu 22.04 LTS | Long-term support; Python 3.10+ pre-installed |
| Standard_LRS disk | Cost-effective SSD storage for dev/test |
| NSG with rules | Security - only allow needed ports |

## Resources Deployed

| Resource | Name | Description |
|----------|------|-------------|
| Virtual Machine | `project-tracker-vm` | 2 vCPU, 8GB RAM, Ubuntu 22.04 LTS |
| Public IP | `project-tracker-pip` | Standard SKU, Static IP |
| Virtual Network | `project-tracker-vnet` | 10.0.0.0/16 |
| Subnet | `default` | 10.0.0.0/24 |
| NSG | `project-tracker-vm-nsg` | Allows SSH (22), HTTP (5000) |
| Network Interface | `project-tracker-vm-nic` | With NSG attached |

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
Access the application at: http://<public-ip>:5000
```

---

## Accessing the Application

After deployment, open your browser:

```
http://<public-ip>:5000
```

**Important:** The Flask application must bind to `0.0.0.0` (not `127.0.0.1`) to be accessible externally. Ensure `app.py` has:

```python
app.run(host='0.0.0.0', port=5000)
```

---

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

### View Application Startup Logs
```bash
az vm run-command invoke \
  -g project-tracker-rg \
  -n project-tracker-vm \
  --command-id RunShellScript \
  --script "journalctl -u project-tracker -n 50"
```

### Connect via SSH
```bash
ssh azureuser@<public-ip>
```

### Restart Application
```bash
az vm run-command invoke \
  -g project-tracker-rg \
  -n project-tracker-vm \
  --command-id RunShellScript \
  --script "systemctl restart project-tracker"
```

### Check NSG Rules
```bash
az network nsg rule list -g project-tracker-rg --nsg-name project-tracker-vm-nsg -o table
```

### Verify NSG is Attached to NIC
```bash
az network nic show -g project-tracker-rg -n project-tracker-vm-nic --query "networkSecurityGroup"
```

### Get Public IP
```bash
az network public-ip show -g project-tracker-rg -n project-tracker-pip --query ipAddress
```

---

## Cleaning Up

To delete all resources:

```bash
# Using script
./deploy.sh --cleanup

# Or directly
az group delete --name project-tracker-rg --yes
```

---

## Configuration

### Current Configuration

- **Location:** Canada Central
- **VM Size:** Standard_D2s_v3 (2 vCPU, 8GB RAM)
- **Public IP:** Standard SKU (static)
- **Port:** 5000

### Change VM Size
Edit `main.bicep` and modify:
```bicep
var vmSize = 'Standard_D2s_v3'  // Change to desired size
```

### Change Location
Edit `deploy.ps1` or `deploy.sh`:
```bash
LOCATION="canadacentral"  # Change to desired region
```

### Change Prefix
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

## Important Notes

1. **Flask Host Binding:** The application must use `host='0.0.0.0'` to be accessible externally. Do not use `127.0.0.1` or `localhost`.

2. **Standard SKU Public IP:** Requires explicit NSG association with the network interface. The template handles this automatically.

3. **NSG Rules:** Inbound rules must allow traffic on port 5000 from `Internet` source.

4. **Subscription Limits:** Basic SKU public IPs have limits in some regions. Use Standard SKU for production.

---

## Application Details

- **Source Code:** https://github.com/damarc-admin/project-tracker/tree/onboard
- **Framework:** Flask
- **Port:** 5000
- **Data Storage:** CSV files (projects.csv, tasks.csv, users.csv, audit.csv)
