@description('Required: Frontdoor profile name')
param frontDoorName string

@description('Required: CustomDomain name')
param customDomainName string

@description('Required: Endpoint name')
param endpointName string

@description('Required: CustomDomain name')
param hostName string

param originGroupName string

param originObject object

param routeObject object


// esisting

resource frontDoor 'Microsoft.Cdn/profiles@2022-11-01-preview' existing = {
  name: frontDoorName
}

// resource originGroup 'Microsoft.Cdn/profiles/origingroups@2022-11-01-preview' existing = {
//   name: originGroupName
//   parent: frontDoor
// }

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2022-11-01-preview' existing = {  
  name: endpointName
  parent: frontDoor
}

// resources

resource originGroup 'Microsoft.Cdn/profiles/origingroups@2022-11-01-preview' = {
  parent: frontDoor
  name: originGroupName
  properties: {
    loadBalancingSettings: {
      sampleSize: originObject.sampleSize
      successfulSamplesRequired: originObject.successfulSamplesRequired
      additionalLatencyInMilliseconds: originObject.additionalLatencyInMilliseconds
    }
    healthProbeSettings: {
      probePath: originObject.probePath
      probeRequestType: originObject.probeRequestType
      probeProtocol: originObject.probeProtocol
      probeIntervalInSeconds: originObject.probeIntervalInSeconds
    }
    sessionAffinityState: originObject.sessionAffinityState
  }
}


resource customDomain 'Microsoft.Cdn/profiles/customdomains@2022-11-01-preview' = {
  name: customDomainName
  parent:frontDoor
  properties: {
    hostName: hostName
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
    }
  }
}

resource origin 'Microsoft.Cdn/profiles/origingroups/origins@2022-11-01-preview' = {
  parent: originGroup
  name: originObject.name
  properties: {
    hostName: originObject.hostName
    httpPort: originObject.httpPort
    httpsPort: originObject.httpsPort
    originHostHeader: originObject.originHostHeader
    priority: originObject.priority
    weight: originObject.weight
    enabledState: originObject.enabledState
    sharedPrivateLinkResource: empty(originObject.privateLinkResourceId) ? {} : {
      privateLink: {
        id: originObject.privateLinkResourceId
      }
      privateLinkLocation: originObject.privateLinkLocation
      status: 'Approved'
      requestMessage: 'Please approve this request to allow Front Door to access the container app'
    }
    enforceCertificateNameCheck: true
  }
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2022-11-01-preview' = {
  parent: endpoint
  name: routeObject.name
  properties: {
    customDomains: [
      {
        id: customDomain.id
      }
    ]
    originGroup: {
      id: originGroup.id
    }
    originPath: routeObject.originPath
    ruleSets: routeObject.ruleSets
    supportedProtocols: routeObject.supportedProtocols
    patternsToMatch: routeObject.patternsToMatch
    forwardingProtocol: routeObject.forwardingProtocol
    linkToDefaultDomain: routeObject.linkToDefaultDomain
    httpsRedirect: routeObject.httpsRedirect
    enabledState: 'Enabled'
  }
  dependsOn:[
    origin
  ]
}

   
   /* -----------
     Outputs     
     ----------- */
   
   output customDomainId string = customDomain.id
   output originId string = origin.id
   output routeId string = route.id
   