// Bicep file for creating an Azure API Management instance
param apiManagementServiceName string = 'cdtweb${uniqueString(utcNow('u'))}'
param publisherEmail string = 'massimo.crippa@codit.eu'
param publisherName string = 'CoditBasic'
param location string = 'westeurope'

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

output apimResourceId string = apim.id
