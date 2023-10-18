targetScope = 'subscription'

param project string
param location string = deployment().location
param tags object = {}

// Variables
var projectName = project
var deploymentName = deployment().name
var resourceGroupName = 'rg-${projectName}'
var appChatName = 'chat-${projectName}'

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
// Container Apps Application (chatbotui)
// ---------------------------------------------------------
module modAppChatbotUI 'modules/app-chatbotui.bicep' = {
  name: take('${deploymentName}-chat', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    appName: appChatName
    replicas: 1
    location:location
    tags:tags
    environmentId: '/subscriptions/c1537527-c126-428d-8f72-1ac9f2c63c1f/resourceGroups/rg-holafay/providers/Microsoft.App/managedEnvironments/env-holafay'
    openAI_Key: '2af3ea4065dd492c820c6ae8df65705b'
    openAI_Host: 'https://ai-holafay.openai.azure.com'
    openAI_DeploymentId: chatGptDeploymentName
    openAI_ModelName: chatGptModelName
  }
}



// module modDeploymentScript 'modules/deployment-script.bicep' = {
//   name: take('${deploymentName}-script', 58)
//   scope : resourceGroup(resourceGroupName)
//   params: {
//     managedIdentityName: 'msiholafay'
//     location: location
//     tags: tags
//   }  
// }

output rgName string = modResourceGroup.outputs.name
//output gwEsists bool = modDeploymentScript.outputs.exists
