param vnetId string
param domain string
param nicName string = ''


resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' existing = {
  name: nicName
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: domain
  location: 'Global'
}

resource privateDnsZoneEntry 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: '*'
  parent: privateDnsZone
  properties: {
    aRecords: [
      {
        ipv4Address: nic.properties.ipConfigurations[0].properties.privateIPAddress
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
