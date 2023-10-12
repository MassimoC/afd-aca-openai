@description('Required. The name of the Managed Identity to create.')
param managedIdentityName string
param location string

param expiryDate string = '2023-10-14T22:00:00Z'
param gwName string = 'gwapim'
param apimName string = 'apim-holafay'
param rgName string = 'rg-holafay'
param sid string = 'c1537527-c126-428d-8f72-1ac9f2c63c1f'

@description('Optional: Tags')
param tags object = {}
@description('Optional: Current Time.')
param utcValue string = utcNow()

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource certDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deploymentScript'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.47.0'
    timeout: 'PT10M'
    cleanupPreference: 'Always'
    retentionInterval: 'P1D'
    environmentVariables: [
      {
        name: 'expiryDate'
        value: expiryDate
      }
      {
        name: 'gwName'
        value: gwName
      }
      {
        name: 'apimName'
        value: apimName
      }
      {
        name: 'rgName'
        value: rgName
      }
      {
        name: 'sid'
        value: sid
      }
    ]
    scriptContent: loadTextContent('../scripts/get-token.sh')
  }
  tags: tags
}

output exists bool = length(certDeploymentScript.properties.outputs.ApimToken) > 0
output apimToken string = certDeploymentScript.properties.outputs.ApimToken
