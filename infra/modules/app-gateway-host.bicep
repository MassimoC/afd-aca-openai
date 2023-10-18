param apimName string
param projectCode string
param isExternalIngress bool = true
param location string = resourceGroup().location
param environmentId string
@secure()
param gatewayToken string
param gatewayTag string = 'latest'

param secrets array = [
  {
    name: 'apim-gateway-on-aca-token'
    value: gatewayToken
  }
]

var env = [
  {
      name: 'config.service.endpoint'
      value: '${apimName}.configuration.azure-api.net'
  }
  {
    name: 'config.service.auth'
    secretRef: secrets[0].name
  }
]

resource apimIngress 'Microsoft.App/containerApps@2022-10-01' = {
  name: '${projectCode}-ingress'
  location: location
  properties: {
    environmentId: environmentId
    configuration: {
      activeRevisionsMode:'Single'
      ingress: {
        allowInsecure:false
        external: isExternalIngress
        targetPort: 8080
        transport: 'auto'
      }
    secrets: secrets
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azure-api-management/gateway:${gatewayTag}'
          name: '${projectCode}-ingress'
          env: env
          resources:{
            cpu: json('0.5')
            memory:'1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 4
        rules:[
          {
            name: 'http'
            http:{
              metadata:{
                concurrentRequests: '1000'
              }
            }
          }
        ]
      }
    }
  }
}

output fqdn string = apimIngress.properties.configuration.ingress.fqdn
output ingressName string = apimIngress.name
