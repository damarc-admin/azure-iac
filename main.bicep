@description('Location for all resources')
param location string = 'canadacentral'

@description('Username for the virtual machine')
param adminUsername string = 'azureuser'

@description('SSH key or password for the virtual machine')
@secure()
param adminPassword string

@description('Prefix for the load balancer')
param loadBalancerPrefix string = 'project-tracker'

var virtualMachineName = '${loadBalancerPrefix}-vm'
var networkInterfaceName = '${virtualMachineName}-nic'
var networkSecurityGroupName = '${virtualMachineName}-nsg'
var publicIpAddressName = '${loadBalancerPrefix}-pip'
var vnetName = '${loadBalancerPrefix}-vnet'
var subnetName = 'default'

var vmSize = 'Standard_D2s_v3'

var appServicePort = 5000

var installScript = '''
#!/bin/bash
set -e

apt-get update
apt-get install -y python3 python3-pip git

cd /opt
git clone https://github.com/damarc-admin/project-tracker.git --branch onboard --single-branch project-tracker

cd /opt/project-tracker
pip3 install -r requirements.txt

cat > /opt/project-tracker/start.sh << 'SCRIPTEOF'
#!/bin/bash
cd /opt/project-tracker
python3 app.py
SCRIPTEOF
chmod +x /opt/project-tracker/start.sh

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

echo "Application deployed successfully"
'''

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1001
          direction: 'Inbound'
        }
      }
      {
        name: 'allow-http'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '${appServicePort}'
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

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: publicIpAddressName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: loadBalancerPrefix
    }
  }
  sku: {
    name: 'Basic'
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddress.id
          }
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        name: '${virtualMachineName}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}

resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  parent: virtualMachine
  name: 'install-app'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    settings: {
      commandToExecute: 'bash -c "${installScript}"'
    }
  }
}

output publicIPAddress string = publicIpAddress.properties.ipAddress
