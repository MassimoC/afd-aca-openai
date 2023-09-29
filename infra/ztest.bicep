targetScope = 'subscription'

param project string
param customDomainSuffix string = ''
param location string = deployment().location
param tags object = {}


// Variables
var projectName = project
var deploymentName = deployment().name
var resourceGroupName = 'rg-holabay'
var openAIName = 'ai-${projectName}-model'



//var resourceToken = toLower(uniqueString(subscription().id, project, location))
//var openAiSkuName = 'S0'
var chatGptDeploymentName = 'chat'
var chatGptModelName = 'gpt-35-turbo'
//var openaiApiKeySecretName = 'openai-apikey'
var chatGptModelVersion='0301'


module modPrivateDnsZone 'CARML/network/private-dns-zone/main.bicep' = {
  name: take('${deploymentName}-dnszone', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    name: 'privatelink.openai.azure.com'
    location:'global'
  }  
}
var privateDnsZoneGroup = {
  privateDNSResourceIds: [ modPrivateDnsZone.outputs.resourceId ]
}
module openAi  'CARML/cognitive-services/account/main.bicep' = {
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
        subnetResourceId : 'subscriptions/c1537527-c126-428d-8f72-1ac9f2c63c1f/resourceGroups/rg-holabay/providers/Microsoft.Network/virtualNetworks/vnet-holabay/subnets/FourthSubnet'
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
}
