// ===================================================================
// Azure Bicep Template - Project Tracker VM Deployment
// ===================================================================
// This template deploys a Flask-based Project Tracker application
// on an Azure Virtual Machine with public IP access.
// ===================================================================

// ---------------------------------------------------------------------------
// PARAMETERS
// ---------------------------------------------------------------------------
// Input parameters that can be customized during deployment

// Azure region where resources will be deployed
@description('Location for all resources')
param location string = 'canadacentral'

// Administrator username for the virtual machine
@description('Username for the virtual machine')
param adminUsername string = 'azureuser'

// Administrator password for the virtual machine (secured)
@description('SSH key or password for the virtual machine')
@secure()
param adminPassword string

// Prefix for all resource names (allows multiple deployments)
@description('Prefix for all resource names')
param loadBalancerPrefix string = 'project-tracker'

// ---------------------------------------------------------------------------
// VARIABLES
// ---------------------------------------------------------------------------
// Internal variables derived from parameters

// VM name based on prefix
var virtualMachineName = '${loadBalancerPrefix}-vm'

// Network interface name
var networkInterfaceName = '${virtualMachineName}-nic'

// Network Security Group name
var networkSecurityGroupName = '${virtualMachineName}-nsg'

// Public IP address name
var publicIpAddressName = '${loadBalancerPrefix}-pip'

// Virtual network name
var vnetName = '${loadBalancerPrefix}-vnet'

// Subnet name within the virtual network
var subnetName = 'default'

// VM size - Standard_D2s_v3: 2 vCPU, 8GB RAM
var vmSize = 'Standard_D2s_v3'

// Application port (Flask default)
var appServicePort = 5000

// ---------------------------------------------------------------------------
// CUSTOM SCRIPT FOR APPLICATION INSTALLATION
// ---------------------------------------------------------------------------
// This script runs on the VM after creation to install and configure the app
// Note: Flask app must use host='0.0.0.0' to be accessible externally
var installScript = '''
#!/bin/bash
set -e

# Update package lists and install required packages
# - python3: Python runtime
# - git: For cloning the repository
# - curl: For downloading pip installer
apt-get update
apt-get install -y python3 git curl

# Install pip (Python package manager)
# Using get-pip.py as python3-pip may not be available in Ubuntu 22.04
curl -sS https://bootstrap.pypa.io/get-pip.py | python3

# Clone the Project Tracker application from GitHub
cd /opt
git clone https://github.com/damarc-admin/project-tracker.git --branch onboard --single-branch project-tracker

# Install Python dependencies
# --break-system-packages: Required for pip to install in system Python
# --ignore-installed blinker: Avoids conflicts with system-installed blinker
cd /opt/project-tracker
pip3 install --break-system-packages --ignore-installed blinker -r requirements.txt

# Create startup script
cat > /opt/project-tracker/start.sh << 'SCRIPTEOF'
#!/bin/bash
cd /opt/project-tracker
python3 app.py
SCRIPTEOF
chmod +x /opt/project-tracker/start.sh

# Create systemd service for automatic startup
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

# Enable and start the application service
systemctl daemon-reload
systemctl enable project-tracker
systemctl start project-tracker

echo "Application deployed successfully"
'''

// ---------------------------------------------------------------------------
// VIRTUAL NETWORK
// ---------------------------------------------------------------------------
// Creates a virtual network with a subnet for the VM
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'  // Entire network range
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'  // Subnet range
          // Attach NSG to subnet for security
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// NETWORK SECURITY GROUP (NSG)
// ---------------------------------------------------------------------------
// Security rules to control inbound/outbound traffic
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      // Allow SSH access from internet (for VM administration)
      {
        name: 'allow-ssh'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'        // Any source port
          destinationPortRange: '22'   // SSH port
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1001              // Lower = higher priority
          direction: 'Inbound'
        }
      }
      // Allow HTTP access to Flask application
      {
        name: 'allow-http'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '${appServicePort}'  // Port 5000
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1002
          direction: 'Inbound'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// PUBLIC IP ADDRESS
// ---------------------------------------------------------------------------
// Static public IP for accessing the VM from the internet
// Uses Standard SKU - required for NSG attachment to NIC
resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: publicIpAddressName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'  // Static IP (won't change)
    dnsSettings: {
      domainNameLabel: loadBalancerPrefix  // DNS label for public access
    }
  }
  sku: {
    name: 'Standard'  // Standard SKU required for production
  }
}

// ---------------------------------------------------------------------------
// NETWORK INTERFACE
// ---------------------------------------------------------------------------
// Connects VM to the virtual network and attaches public IP + NSG
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'  // DHCP - IP assigned automatically
          // Attach public IP to this NIC
          publicIPAddress: {
            id: publicIpAddress.id
          }
          // Connect to virtual network subnet
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
        }
      }
    ]
    // Attach NSG directly to NIC (required for Standard SKU public IP)
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

// ---------------------------------------------------------------------------
// VIRTUAL MACHINE
// ---------------------------------------------------------------------------
// Creates the compute instance with Ubuntu OS
resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize  // 2 vCPU, 8GB RAM
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      // Ubuntu 22.04 LTS image from Canonical
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      // OS disk configuration
      osDisk: {
        name: '${virtualMachineName}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'  // Standard HDD storage
        }
      }
    }
    networkProfile: {
      // Attach network interface
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// CUSTOM SCRIPT EXTENSION
// ---------------------------------------------------------------------------
// Executes the installScript on the VM after it is created
resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  parent: virtualMachine
  name: 'install-app'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    settings: {
      // Execute the installScript defined above
      commandToExecute: 'bash -c "${installScript}"'
    }
  }
}

// ---------------------------------------------------------------------------
// OUTPUTS
// ---------------------------------------------------------------------------
// Returns the public IP address after deployment

// Public IP address of the deployed VM
output publicIPAddress string = publicIpAddress.properties.ipAddress
