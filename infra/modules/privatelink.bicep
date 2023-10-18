// Parameters
param name string
param location string
param loadBalancerName string
//MMCR
//param loadBalancerResourceGroupName string
param subnetId string
param peSubnetId string
param acaDefaultDomainName string
param privateIPAllocationMethod string = 'Dynamic'
param privateIPAddressVersion string = 'IPv4'
param tags object = {}

param pepName string


var containerAppsDefaultDomainArray = split(acaDefaultDomainName, '.')
var containerAppsNameIdentifier = containerAppsDefaultDomainArray[lastIndexOf(containerAppsDefaultDomainArray, location)-1]
var containerAppsManagedResourceGroup = 'MC_${containerAppsNameIdentifier}-rg_${containerAppsNameIdentifier}_${location}'

// Resources
resource loadBalancer 'Microsoft.Network/loadBalancers@2022-07-01' existing = {
  name: loadBalancerName
  scope: resourceGroup(containerAppsManagedResourceGroup)
}

resource privateLinkService 'Microsoft.Network/privateLinkServices@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    autoApproval: {
      subscriptions: [
        subscription().subscriptionId
      ]
    }
    visibility: {
      subscriptions: [
        subscription().subscriptionId
      ]
    }
    fqdns: []
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: loadBalancer.properties.frontendIPConfigurations[0].id
      }
    ]   
    ipConfigurations: [
      {
        name: 'Default'
        properties: {
          privateIPAllocationMethod: privateIPAllocationMethod
          subnet: {
            id: subnetId
          }
          primary: true
          privateIPAddressVersion: privateIPAddressVersion
        }
      }
    ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: pepName
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'privalink-container-apps'
        properties: {
          privateLinkServiceId: privateLinkService.id
        }
      }
    ]
  }
}

// Outputs
output id string = privateLinkService.id
output name string = privateLinkService.name
output pepNICName string = split(privateEndpoint.properties.networkInterfaces[0].id, '/')[8]
