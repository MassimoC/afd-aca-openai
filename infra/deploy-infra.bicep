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
var appInsightsName = 'ains-${projectName}'
var acaEnvironmentName = 'env-${projectName}'
var openAIName = 'ai-${projectName}'
var apimName = 'apim-${projectName}'
var aciName  = 'aci-${projectName}'
var acrName  = projectName
var infrastructureResourceGroupName = 'ME_${resourceGroupName}'
var privateLinkServiceName = 'pls-${projectName}'
var pepName = 'pe-${acaEnvironmentName}'
var loadBalancerName = 'kubernetes-internal'
var frontDoorName = 'afd${projectName}'
var msiName = 'msi${projectName}'
var appChatName = 'chat-${projectName}'
var pipName = 'pip-${projectName}-apimstv2'

var chatGptDeploymentName = 'gpt${projectName}'
var chatGptModelName = 'gpt-35-turbo'
var chatGptModelVersion='0301'

// ---------------------------------------------------------
// Resource Group
// ---------------------------------------------------------
module modResourceGroup 'CARML/resources/resource-group/main.bicep' = {
  name: take('${deploymentName}-rg', 58)
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}
// ---------------------------------------------------------
// Log Analytics Workspace
// ---------------------------------------------------------
module modLogAnalytics 'CARML/operational-insights/workspace/main.bicep' = {
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

// ---------------------------------------------------------
// Application Insights
// ---------------------------------------------------------
module modApplicationInsights 'CARML/insights/component/main.bicep' = {
  name: take('${deploymentName}-ains', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name:appInsightsName
    workspaceResourceId: modLogAnalytics.outputs.resourceId
    retentionInDays:30
    location:location
    tags: tags
  }
  dependsOn: [
    modLogAnalytics
  ]
}

// ---------------------------------------------------------
// Managed Identity
// ---------------------------------------------------------
module modManagedIdentity 'modules/identities.bicep' = {
  name: take('${deploymentName}-msi', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: msiName
    location:location
    tags:tags
  }
}

// ---------------------------------------------------------
// Container Registry
// ---------------------------------------------------------
module containerRegistry 'modules/registry.bicep' = {
  name: take('${deploymentName}-acr', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: acrName
    adminUserEnabled: true
    workspaceId: modLogAnalytics.outputs.resourceId
    location: location
    tags: tags
  }
}

// ---------------------------------------------------------
// Networking
// ---------------------------------------------------------
module modNetworking 'modules/network.bicep' = {
  name: take('${deploymentName}-networking', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    virtualNetworkName: virtualNetworkName
    natGatewayName: natGatewayName
    natGatewayEnabled: false
    createAcrPrivateEndpoint:true
    acrPrivateEndpointName: 'pe-acr-${acrName}'
    acrId: containerRegistry.outputs.resourceId
    pipName:pipName
    location: location
  }
  dependsOn: [
    modResourceGroup
  ]
}

// ---------------------------------------------------------
// Sort of jumpbox for testing purposes
// ---------------------------------------------------------
module modAci 'modules/aci.bicep' = {
  name: take('${deploymentName}-test', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: aciName
    subnetId: modNetworking.outputs.testSubnetId
    location: location
  }
  dependsOn: [
    modNetworking
  ]
}

// ---------------------------------------------------------
// ACA environment GEN1
// ---------------------------------------------------------
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
    infrastructureSubnetId: modNetworking.outputs.acagen1SubnetId
  }
  dependsOn: [ 
    modResourceGroup 
    modNetworking
    modLogAnalytics
  ]
}

// ---------------------------------------------------------
// API Management
// ---------------------------------------------------------
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
    subnetResourceId : modNetworking.outputs.apimSubnetId
    minApiVersion: '2021-08-01'
  }
  dependsOn:[
    modResourceGroup 
    modNetworking
    modLogAnalytics
  ]
}

// ---------------------------------------------------------
// Private DNS Zone for APIM 
// ---------------------------------------------------------

module apimDns 'modules/privatednsapim.bicep' = {
  name: take('${deploymentName}-apimdns', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    ipv4Address: modApim.outputs.privateIPs[0]
    vnetId: modNetworking.outputs.virtualNetworkId
    domain: 'azure-api.net'
    apimServiceName: modApim.outputs.name
  }
  dependsOn: [
    modApim
  ]  
}

module apimDns2 'modules/privatednsapim.bicep' = {
  name: take('${deploymentName}-apimdns2', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    ipv4Address: modApim.outputs.privateIPs[0]
    vnetId: modNetworking.outputs.virtualNetworkId
    domain: 'configuration.azure-api.net'
    apimServiceName: modApim.outputs.name
  }
  dependsOn: [
    modApim
  ]  
}

module apimDns3 'modules/privatednsapim.bicep' = {
  name: take('${deploymentName}-apimdns3', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    ipv4Address: modApim.outputs.privateIPs[0]
    vnetId: modNetworking.outputs.virtualNetworkId
    domain: 'management.azure-api.net'
    apimServiceName: modApim.outputs.name
  }
  dependsOn: [
    modApim
  ]  
}

// ---------------------------------------------------------
// Private link for Frontdoor (used also for internal traffic to ACA)
// ---------------------------------------------------------
module modPrivateLinkService 'modules/privatelink.bicep' = {
  name: take('${deploymentName}-pls', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: privateLinkServiceName
    loadBalancerName: loadBalancerName
    //loadBalancerResourceGroupName: infrastructureResourceGroupName
    acaDefaultDomainName: modAcaEnvironment.outputs.defaultDomain
    subnetId: modNetworking.outputs.plsSubnetId
    peSubnetId :modNetworking.outputs.peSubnetId
    apimResourceId: modApim.outputs.resourceId
    location: location
    tags: tags
    pepName:pepName
  }
  dependsOn: [
    modAcaEnvironment
  ]
}

// ---------------------------------------------------------
// Private DNS ACA (private DNS zone, DNS entry and VNET link)
// ---------------------------------------------------------
module pdns 'modules/privatedns.bicep' = {
  name: take('${deploymentName}-pdns', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    vnetId: modNetworking.outputs.virtualNetworkId
    domain: modAcaEnvironment.outputs.defaultDomain
    nicName: modPrivateLinkService.outputs.pepNICName
  }
  dependsOn: [
    modPrivateLinkService
    modAcaEnvironment
  ]  
}

// ---------------------------------------------------------
// Container Apps Application (podinfo)
// ---------------------------------------------------------
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

// ---------------------------------------------------------
// Private DNS Zone for OpenAI
// ---------------------------------------------------------
module modPrivateDnsZone 'CARML/network/private-dns-zone/main.bicep' = {
  name: take('${deploymentName}-dnszone', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: 'privatelink.openai.azure.com'
    location:'global'
    virtualNetworkLinks: [
      {
        name: 'openai-vnet-link'
        virtualNetworkResourceId : modNetworking.outputs.virtualNetworkId
        registrationEnabled: true
      }
    ]
  }  
  dependsOn:[
    modNetworking
  ]
}

var privateDnsZoneGroup = {
  privateDNSResourceIds: [ modPrivateDnsZone.outputs.resourceId ]
}

// ---------------------------------------------------------
// Azure OpenAI
// ---------------------------------------------------------
module modOpenAI  'CARML/cognitive-services/account/main.bicep' = {
  name: take('${deploymentName}-openai', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: openAIName
    customSubDomainName: openAIName
    kind: 'OpenAI'
    sku:'S0'
    disableLocalAuth:false
    location:'francecentral'
    tags:tags
    publicNetworkAccess:'Disabled'
    privateEndpoints: [
      {
        subnetResourceId : modNetworking.outputs.peSubnetId
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


// ---------------------------------------------------------
// Container Apps Application (chatbotui)
// ---------------------------------------------------------

var openAIHost = substring(modOpenAI.outputs.endpoint, 0, length(modOpenAI.outputs.endpoint)-1)

module modAppChatbotUI 'modules/app-chatbotui.bicep' = {
  name: take('${deploymentName}-chat', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    appName: appChatName
    replicas: 1
    location:location
    tags:tags
    environmentId:modAcaEnvironment.outputs.resourceId
    openAI_Key: modOpenAI.outputs.securityKey
    openAI_Host: openAIHost
    openAI_DeploymentId: chatGptDeploymentName
    openAI_ModelName: chatGptModelName
    userAssignedIdentityId: modManagedIdentity.outputs.miResourceId
    acrName: containerRegistry.outputs.name
  }
  dependsOn: [modOpenAI]
}

// ---------------------------------------------------------
// APIM self hosted gateway
// ---------------------------------------------------------

var gwName = 'gwapim'

module createApimGateway 'modules/app-gateway-create.bicep' = {
  name: take('${deploymentName}-apimgw', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    apiName: 'test'
    apiServicemName: modApim.outputs.name
    gatewayName: gwName
    enableAppInsights: true
    appInsightsResourceId: modApplicationInsights.outputs.resourceId
    appInsightsKey: modApplicationInsights.outputs.instrumentationKey
  }
  dependsOn: [ 
    modApim
  ]
}

module modDeploymentScript 'modules/deployment-script.bicep' = {
  name: take('${deploymentName}-script', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    managedIdentityName: 'msiholafay'
    location: location
    tags: tags
    expiryDate: '2024-01-10T22:00:00Z'
    gwName: gwName
    apimName: modApim.outputs.name
    rgName: modResourceGroup.outputs.name
    sid: subscription().subscriptionId
  }
  dependsOn: [ 
    modApim
  ]
}

module modGatewayOnAca 'modules/app-gateway-host.bicep' = {
  name: take('${deploymentName}-acagw', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    apimName: modApim.outputs.name
    location: location
    projectCode: projectName
    environmentId: modAcaEnvironment.outputs.resourceId
    gatewayToken: modDeploymentScript.outputs.apimToken
  }
  dependsOn: [ 
    modApim
    modAcaEnvironment
  ]
}

// ---------------------------------------------------------
// Azure Frontdoor premium
// ---------------------------------------------------------

// APIM internal and PLS is mutually exclusive (one or the other)
var apimHostName = split(modApim.outputs.gatewayURL, '/')[2]

// open api REST api do not expose a probe endpoint
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
    originHostName: modAppChatbotUI.outputs.ingressFqdn
    probePath: '/'
    linkToDefaultDomain:'Disabled'
  }
  {
    domainprefix: 'lab3'
    originHostName: modGatewayOnAca.outputs.fqdn
    probePath: '/status-0123456789abcdef'
    linkToDefaultDomain:'Disabled'
  }
  {
    domainprefix: 'lab4'
    originHostName: apimHostName
    probePath: '/status-0123456789abcdef'
    linkToDefaultDomain:'Disabled'
  }  
  // {
  //   domainprefix: 'lab2'
  //   originHostName: apimHostName
  //   probePath: '/status-0123456789abcdef'
  //   linkToDefaultDomain:'Disabled'
  // }
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
