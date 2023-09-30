// Parameters
@description('Specifies the name of the virtual network.')
param virtualNetworkName string

@description('Specifies the address prefixes of the virtual network.')
param virtualNetworkAddressPrefixes string = '10.0.0.0/8'

@description('Specifies the location.')
param location string = resourceGroup().location

@description('Specifies the resource tags.')
param tags object = {}

// ********** ACA Subnets ***********

param acagen2SubnetName string = 'acagen2Subnet'
param acagen2SubnetAddressPrefix string = '10.0.0.0/27'

param testSubnetName string = 'testSubnet'
param testSubnetAddressPrefix string = '10.1.0.0/27'

param apimSubnetName string = 'apimSubnet'
param apimSubnetAddressPrefix string = '10.2.0.0/27'

param acagen1SubnetName string = 'acagen1Subnet'
param acagen1SubnetAddressPrefix string = '10.3.0.0/23'

// ********** PE Subnets ***********


param peSubnetName string = 'PrivateEndpointSubnet'
param peSubnetAddressPrefix string = '10.4.0.0/27'
param peSubnetNsgName string = 'peSubnetNsg'

// ********** NAT Gateway ***********

param natGatewayName string
param natGatewayEnabled bool = false
param natGatewayZones array = []
param natGatewayPublicIps int = 1
param natGatewayIdleTimeoutMins int = 30

// ********** ACR ***********

@description('Specifies whether to create a private endpoint for the Azure Container Registry')
param createAcrPrivateEndpoint bool = false

@description('Specifies the name of the private link to the Azure Container Registry.')
param acrPrivateEndpointName string = 'AcrPrivateEndpoint'

@description('Specifies the resource id of the Azure Container Registry.')
param acrId string = ''

var acagen2Subnet = {
  name: acagen2SubnetName
  properties: {
    addressPrefix: acagen2SubnetAddressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    natGateway: natGatewayEnabled ? {
      id: natGateway.id
    } : null
    delegations: [
      {
        name: 'aka-delegation'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
}
var testSubnet = {
  name: testSubnetName
  properties: {
    addressPrefix: testSubnetAddressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    natGateway: natGatewayEnabled ? {
      id: natGateway.id
    } : null
    delegations:[
      {
        name: 'aci-delegation'
        properties:{
          serviceName:'Microsoft.ContainerInstance/containerGroups'
        }
      }
    ]
  }
}
var apimSubnet = {
  name: apimSubnetName
  properties: {
    addressPrefix: apimSubnetAddressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    natGateway: natGatewayEnabled ? {
      id: natGateway.id
    } : null
    delegations: [
    ]
  }
}
var acagen1Subnet = {
  name: acagen1SubnetName
  properties: {
    addressPrefix: acagen1SubnetAddressPrefix
    privateLinkServiceNetworkPolicies: 'Disabled'
    delegations: []
  }
}
var peSubnet = {
  name: peSubnetName
  properties: {
    addressPrefix: peSubnetAddressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

var subnets = union(
  array(acagen2Subnet),
  array(testSubnet),
  array(apimSubnet),
  array(acagen1Subnet),
  array(peSubnet)
)


// Network Security Groups
resource peSubnetNsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: peSubnetNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowSshInbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefixes
      ]
    }
    subnets: subnets
  }
}

// NAT Gateway
resource natGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2021-08-01' = [for i in range(0, natGatewayPublicIps): if (natGatewayEnabled) {
  name: natGatewayPublicIps == 1 ? '${natGatewayName}pip' : '${natGatewayName}pip${i + 1}'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: !empty(natGatewayZones) ? natGatewayZones : []
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}]

resource natGateway 'Microsoft.Network/natGateways@2021-08-01' = if (natGatewayEnabled) {
  name: natGatewayName
  location: location
  sku: {
    name: 'Standard'
  }
  zones: !empty(natGatewayZones) ? natGatewayZones : []
  properties: {
    publicIpAddresses: [for i in range(0, natGatewayPublicIps): {
      id: natGatewayPublicIp[i].id
    }]
    idleTimeoutInMinutes: natGatewayIdleTimeoutMins
  }
  dependsOn: [
    natGatewayPublicIp
  ]
}

// Private DNS Zones
resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.${toLower(environment().name) == 'azureusgovernment' ? 'azurecr.us' : 'azurecr.io'}'
  location: 'global'
  tags: tags
}

// Virtual Network Links
resource acrPrivateDnsZoneVirtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrPrivateDnsZone
  name: 'link_to_${toLower(virtualNetworkName)}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Private Endpoints
resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = if (createAcrPrivateEndpoint) {
  name: acrPrivateEndpointName
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: acrPrivateEndpointName
        properties: {
          privateLinkServiceId: acrId
          groupIds: [
            'registry'
          ]
        }
      }
    ]
    subnet: {
      id: '${vnet.id}/subnets/${peSubnetName}'
    }
  }
}

resource acrPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = if (createAcrPrivateEndpoint) {
  parent: acrPrivateEndpoint
  name: 'acrPrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'dnsConfig'
        properties: {
          privateDnsZoneId: acrPrivateDnsZone.id
        }
      }
    ]
  }
}

// Outputs
output virtualNetworkId string = vnet.id
output virtualNetworkName string = vnet.name
output acagen2SubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, acagen2SubnetName)
output testSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, testSubnetName)
output apimSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, apimSubnetName)
output acagen1SubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, acagen1SubnetName)
output peSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, peSubnetName)
output acagen2SubnetName string = acagen2SubnetName
output testSubnetName string = testSubnetName
output apimSubnetName string = apimSubnetName
output acagen1SubnetName string = acagen1SubnetName
output peSubnetName string = peSubnetName
