targetScope = 'subscription'

param project string
param location string = deployment().location
param tags object = {}

// Variables
var projectName = project
var deploymentName = deployment().name
var resourceGroupName = 'rg-${projectName}'

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

module modDeploymentScript 'modules/deployment-script.bicep' = {
  name: take('${deploymentName}-script', 58)
  scope : resourceGroup(resourceGroupName)
  params: {
    managedIdentityName: 'msiholafay'
    location: location
    tags: tags
  }  
}

output rgName string = modResourceGroup.outputs.name
output gwEsists bool = modDeploymentScript.outputs.exists
