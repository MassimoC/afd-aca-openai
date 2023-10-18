param appName string
param environmentId string
param openAI_Key string 
param openAI_Host string
param openAI_DeploymentId string
param openAI_ModelName string
param replicas int = 1
param location string = resourceGroup().location
param tags object= {}

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
            value: openAI_Key
          }
          {
            name: 'OPENAI_API_HOST'
            value: openAI_Host
          }
          {
            name: 'OPENAI_API_TYPE'
            value: 'azure'
          }
          {
            name: 'OPENAI_API_VERSION'
            value: '2023-05-15'
          }
          {
            name: 'AZURE_DEPLOYMENT_ID'
            value: openAI_DeploymentId
          }
          {
            name: 'DEFAULT_MODEL'
            value: openAI_ModelName
          }
          {
            name: 'NEXT_PUBLIC_DEFAULT_SYSTEM_PROMPT'
            value: 'You are ChatGPT, a large language model trained by OpenAI. Follow the user instructions carefully. Respond only about API related topics. Respond using plain text.'
          }
          {
            name: 'NEXT_PUBLIC_DEFAULT_TEMPERATURE'
            value: '1'
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
