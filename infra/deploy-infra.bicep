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
var infrastructureResourceGroupName = '${resourceGroupName}_ME'
var privateLinkServiceName = 'pls-${projectName}'
var pepName = 'pe-${acaEnvironmentName}'
var loadBalancerName = 'kubernetes-internal'
var frontDoorName = 'afd${projectName}'

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
// Networking
// ---------------------------------------------------------
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
// Container Apps Application
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

var chatGptDeploymentName = 'chat'
var chatGptModelName = 'gpt-35-turbo'
var chatGptModelVersion='0301'

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
    originHostName: modApp.outputs.ingressFqdn
    probePath: '/healthz'
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

// ---------------------------------------------------------
// APIM self hosted gateway
// ---------------------------------------------------------

module createApimGateway 'modules/app-gateway-create.bicep' = {
  name: take('${deploymentName}-apimgw', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    apiName: 'test'
    apiServicemName: modApim.outputs.name
    gatewayName: 'gwapim'
    enableAppInsights: true
    appInsightsResourceId: modApplicationInsights.outputs.resourceId
    appInsightsKey: modApplicationInsights.outputs.instrumentationKey
  }
  dependsOn: [ 
    modApim
  ]
}

// Get APIM token

// DEPLOYMENT=$(az deployment group create -g $RESOURCE_GROUP \
//   -f ./bicep/aca-apim-ingress.bicep \
//   -p apimName=$APIM_NAME projectCode=$PROJECT environmentId=$CONTAINERAPPS_ENVIRONMENTID gatewayToken="$GW_TOKEN" gatewayTag="$GATEWAY_TAG")

output rgName string = modResourceGroup.outputs.name
output plsName string = modPrivateLinkService.outputs.name
output plsId string = modPrivateLinkService.outputs.id
