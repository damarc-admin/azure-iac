# Azure IaC - Project Tracker Deployment

This repository contains Infrastructure as Code (IaC) templates to deploy a Flask-based Project Tracker application on Azure Virtual Machines.

## Project Structure

```
azure-iac/
├── bicep/              # Azure Bicep templates
│   ├── main.bicep     # Main Bicep template
│   ├── parameters.json # Deployment parameters
│   ├── deploy.sh      # Bash deployment script
│   ├── deploy.ps1     # PowerShell deployment script
│   └── README.md      # Bicep-specific documentation
│
└── terraform/          # Terraform configurations
    ├── main.tf        # Main Terraform configuration
    ├── variables.tf   # Variable definitions
    ├── outputs.tf     # Output definitions
    ├── deploy.sh      # Bash deployment script
    └── deploy.ps1     # PowerShell deployment script
```

## Choose Your IaC Tool

### Option 1: Bicep (Recommended for Azure)

Bicep is a domain-specific language for declarative deployment of Azure resources. It's native to Azure and provides a cleaner syntax.

**Quick Start:**
```bash
cd bicep
cp parameters.json my.parameters.json
# Edit my.parameters.json with your values
./deploy.sh
```

**Documentation:** [Bicep README](bicep/README.md)

---

### Option 2: Terraform

Terraform is a cloud-agnostic IaC tool that can manage Azure and other cloud providers.

**Quick Start:**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
./deploy.sh
```

**Documentation:** [Terraform README](terraform/README.md)

---

## Architecture

Both templates deploy the same architecture:

```
Internet (port 5000)
       │
       ▼
┌─────────────────┐
│   Public IP     │  Standard SKU, Static
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Network       │  NSG: Allow SSH (22), HTTP (5000)
│   Interface     │
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
| Resource Group | Container for all resources |
| Virtual Network | `10.0.0.0/16` network |
| Subnet | `10.0.0.0/24` subnet |
| NSG | Firewall rules for SSH and HTTP |
| Public IP | Standard SKU, Static |
| Network Interface | Connects VM to network |
| Virtual Machine | Ubuntu 22.04 LTS |
| Custom Script Extension | Installs Flask app |

## Important Notes

1. **Flask Host Binding:** The application must use `host='0.0.0.0'` to be accessible externally. Update `app.py` in the GitHub repo:

   ```python
   app.run(host='0.0.0.0', port=5000)
   ```

2. **Standard SKU Public IP:** Requires explicit NSG attachment to the network interface.

3. **Location:** Resources are deployed to **Canada Central** by default.

## Cleanup

Delete all resources:

**Bicep:**
```bash
cd bicep
./deploy.sh --cleanup
```

**Terraform:**
```bash
cd terraform
./deploy.sh --cleanup
```

## Documentation

- [Bicep Deployment Guide](bicep/README.md)
- [Terraform Deployment Guide](terraform/README.md)
