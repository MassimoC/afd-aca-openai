// Bicep file for creating an Azure API Management instance
param apiManagementServiceName string = 'cdtweb${uniqueString(utcNow('u'))}'
param publisherEmail string = 'massimo.crippa@codit.eu'
param publisherName string = 'CoditBasicV2'
param location string = 'westeurope'

resource apim 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: 'BasicV2'
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

output apimResourceId string = apim.id
