param id string
param environmentId string
param location string
param tags object
param replicas int = 1

var appName = 'app-${id}'

module app  '../CARML/app/container-app/main.bicep' = {
  name: take('${deployment().name}-${appName}', 64)
  params: {
    name: appName
    environmentId: environmentId
    ingressAllowInsecure:true
    ingressExternal:true
    ingressTargetPort: 3000 
    ingressTransport:'auto'
    containers: [
      {
        image: 'ghcr.io/mckaywrigley/chatbot-ui:main'
        name: appName
        resources:{
          cpu: json('2')
          memory:'4Gi'
        }
        env: [
          {
            name: 'OPENAI_API_KEY'
            value: 'string'
          }
          {
            name: 'OPENAI_API_HOST'
            value: 'string'
          }
          {
            name: 'OPENAI_API_TYPE'
            value: 'string'
          }
          {
            name: 'OPENAI_API_VERSION'
            value: 'string'
          }
          {
            name: 'AZURE_DEPLOYMENT_ID'
            value: 'string'
          }
          {
            name: 'OPENAI_ORGANIZATION'
            value: 'string'
          }
          {
            name: 'DEFAULT_MODEL'
            value: 'string'
          }
          {
            name: 'NEXT_PUBLIC_DEFAULT_SYSTEM_PROMPT'
            value: 'string'
          }
          {
            name: 'NEXT_PUBLIC_DEFAULT_TEMPERATURE'
            value: 'string'
          }         
        ]
        probes: [
          {
            type: 'Liveness'
            httpGet: {
              path: '/'
              port: 3000
            }
            periodSeconds: 5
            failureThreshold: 3
            initialDelaySeconds: 10
          }
        ]
      }
    ]
    scaleMinReplicas :replicas
    scaleMaxReplicas: replicas
    location: location
    tags: tags
  }
}

output ingressFqdn string = app.outputs.ingressFqdn
