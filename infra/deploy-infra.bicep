targetScope = 'subscription'

param project string
param customDomainSuffix string
param location string = deployment().location
param tags object = {}

@description('Optional. Workload profiles configured for the Managed Environment.')
param workloadProfiles array = [ 
{
    name: 'Consumption'
    workloadProfileType: 'Consumption'
  }  
]

// Variables
var projectName = project
var deploymentName = deployment().name
var resourceGroupName = 'rg-${projectName}'
var virtualNetworkName = 'vnet-${projectName}'
var natGatewayName = 'nat-${projectName}'
var logAnalyticsName = 'law-${projectName}'
var acaEnvironmentName = 'env-${projectName}'
var openAIName = 'ai-${projectName}'
var apimName = 'apim-${projectName}'
var aciName  = 'aci-${projectName}'
var infrastructureResourceGroupName = '${resourceGroupName}_ME'
var privateLinkServiceName = 'pls-${projectName}'
var pepName = 'pe-${acaEnvironmentName}'
var loadBalancerName = 'kubernetes-internal'
var frontDoorName = 'afd${projectName}'

// Resource Group
module modResourceGroup 'CARML/resources/resource-group/main.bicep' = {
  name: take('${deploymentName}-rg', 58)
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

// Log Analytics Workspace
module modLogAnalytics 'CARML/operational-insights/workspace/main.bicep' ={
  name: take('${deploymentName}-law', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: logAnalyticsName
    location:location
    tags: tags
  }
  dependsOn: [
    modResourceGroup
  ]
}

// Networking
module modNetworking 'modules/network.bicep' = {
  name: take('${deploymentName}-networking', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    virtualNetworkName: virtualNetworkName
    natGatewayName: natGatewayName
    natGatewayEnabled: false
    location: location
  }
  dependsOn: [
    modResourceGroup
  ]
}

// Test
module modAci 'modules/aci.bicep' = {
  name: take('${deploymentName}-test', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: aciName
    subnetId: modNetworking.outputs.secondSubnetId
    location: location
  }
  dependsOn: [
    modNetworking
  ]
}

// ACA environment
module modAcaEnvironment  'CARML/app/managed-environment/main.bicep' = {
  name: take('${deploymentName}-acaenv', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: acaEnvironmentName
    location: location
    tags: tags
    logAnalyticsWorkspaceResourceId: modLogAnalytics.outputs.resourceId
    enableDefaultTelemetry: false
    internal: true
    //infrastructureResourceGroup : infrastructureResourceGroupName
    infrastructureSubnetId: modNetworking.outputs.fourthSubnetId
  }
  dependsOn: [ 
    modResourceGroup 
    modNetworking
    modLogAnalytics
  ]
}

module modApim 'CARML/api-management/service/main.bicep' = {
  name: take('${deploymentName}-apim', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: apimName
    location: location
    tags: tags
    publisherEmail: 'massimo.crippa@codit.eu'
    publisherName: projectName
    virtualNetworkType:'Internal'
    subnetResourceId : modNetworking.outputs.thirdSubnetId
    minApiVersion: '2021-08-01'
  }
  dependsOn:[
    modResourceGroup 
    modNetworking
    modLogAnalytics
  ]
}

module modPrivateLinkService 'modules/privatelink.bicep' = {
  name: take('${deploymentName}-pls', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: privateLinkServiceName
    loadBalancerName: loadBalancerName
    //loadBalancerResourceGroupName: infrastructureResourceGroupName
    acaDefaultDomainName: modAcaEnvironment.outputs.defaultDomain
    subnetId: modNetworking.outputs.fourthSubnetId
    location: location
    tags: tags
    pepName:pepName
  }
  dependsOn: [
    modAcaEnvironment
  ]
}

module pdns 'modules/privatedns.bicep' = {
  name: take('${deploymentName}-pdns', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    pepNicName: modPrivateLinkService.outputs.pepNICName
    vnetId: modNetworking.outputs.virtualNetworkId
    domain: modAcaEnvironment.outputs.defaultDomain
  }
  dependsOn: [
    modPrivateLinkService
    modAcaEnvironment
  ]  
}

module modApp 'modules/app.bicep' = {
  name: take('${deploymentName}-app', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    id: '01'
    replicas: 1
    location:location
    tags:tags
    environmentId:modAcaEnvironment.outputs.resourceId
  }
}

var chatGptDeploymentName = 'chat'
var chatGptModelName = 'gpt-35-turbo'
var chatGptModelVersion='0301'

module modPrivateDnsZone 'CARML/network/private-dns-zone/main.bicep' = {
  name: take('${deploymentName}-dnszone', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: 'privatelink.openai.azure.com'
    location:'global'
  }  
  dependsOn:[
    modNetworking
  ]
}
var privateDnsZoneGroup = {
  privateDNSResourceIds: [ modPrivateDnsZone.outputs.resourceId ]
}

module modOpenAI  'CARML/cognitive-services/account/main.bicep' = {
  name: take('${deploymentName}-openai', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: openAIName
    customSubDomainName: openAIName
    kind: 'OpenAI'
    sku:'S0'
    location:'francecentral'
    tags:tags
    publicNetworkAccess:'Disabled'
    privateEndpoints: [
      {
        subnetResourceId : modNetworking.outputs.fourthSubnetId
        service: 'account'
        privateDnsZoneGroup: privateDnsZoneGroup
      }
    ]
    deployments: [
      {
        name: chatGptDeploymentName
        model: {
          format: 'OpenAI'
          name: chatGptModelName
          version: chatGptModelVersion
        }
        scaleSettings: {
          scaleType: 'Standard'
        }
      }
    ]
  }
  dependsOn:[
    modPrivateDnsZone
    modNetworking
  ]  
}

var apimHostName = split(modApim.outputs.gatewayURL, '/')[2]
var openAIHostName = split(modOpenAI.outputs.endpoint, '/')[2]

var origins  = [
  {
    domainprefix: 'lab1'
    originHostName: modApp.outputs.ingressFqdn
    probePath: '/healthz'
    linkToDefaultDomain:'Enabled'
  }
  {
    domainprefix: 'lab2'
    originHostName: apimHostName
    probePath: '/status-0123456789abcdef'
    linkToDefaultDomain:'Disabled'
  }
]

module frontDoor 'modules/frontdoor.bicep' = {
  name: take('${deploymentName}-afd', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    frontDoorName: frontDoorName
    origins: origins
    privateLinkResourceId: modPrivateLinkService.outputs.id
    workspaceId: modLogAnalytics.outputs.resourceId
    customDomainSuffix:customDomainSuffix
    location: location
    tags: tags
  }
  dependsOn: [
    modPrivateLinkService
    modLogAnalytics
    modApp
    modApim
  ]
}

output rgName string = modResourceGroup.outputs.name
output plsName string = modPrivateLinkService.outputs.name
output plsId string = modPrivateLinkService.outputs.id
