param id string
param environmentId string
param location string
param tags object
param replicas int = 1

var appName = 'app-${id}'

module app01  '../CARML/app/container-app/main.bicep' = {
  name: take('${deployment().name}-${appName}', 64)
  params: {
    name: appName
    environmentId: environmentId
    ingressAllowInsecure:true
    ingressExternal:true
    ingressTargetPort: 9898
    ingressTransport:'auto'
    containers: [
      {
        image: 'ghcr.io/stefanprodan/podinfo:latest'
        name: appName
        resources:{
          cpu: json('1')
          memory:'2Gi'
        }
        probes: [
          {
            type: 'Liveness'
            httpGet: {
              path: '/healthz'
              port: 9898
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

output ingressFqdn string = app01.outputs.ingressFqdn
