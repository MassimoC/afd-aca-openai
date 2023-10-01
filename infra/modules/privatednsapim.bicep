param ipv4Address string
param vnetId string
param domain string
param apimServiceName string



resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: domain
  location: 'Global'
}

resource privateDnsZoneEntry 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: apimServiceName
  parent: privateDnsZone
  properties: {
    aRecords: [
      {
        ipv4Address: ipv4Address
      }
    ]
    ttl: 3600
  }
}

resource vnetLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${domain}-vnet-link'
  parent: privateDnsZone
  location: 'Global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}
