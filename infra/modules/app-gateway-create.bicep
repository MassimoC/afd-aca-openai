param apiServicemName string
param apiName string
param gatewayName string
param enableAppInsights bool = false
param appInsightsKey string = ''
param appInsightsResourceId string = ''


var apiFullName = '${apiName}API'

resource apim 'Microsoft.ApiManagement/service@2021-08-01' existing = {
  name : apiServicemName
}

resource gateway 'Microsoft.ApiManagement/service/gateways@2021-08-01' = {
  name: gatewayName
  parent: apim
  properties:{
    description: 'APIM on Azure Container Apps'
    locationData: {
      name: '${gatewayName}-on-aca'
      countryOrRegion: 'Cloud'
    }
  }
}

resource facadeApi 'Microsoft.ApiManagement/service/apis@2021-08-01' = {
  name: apiFullName
  parent: apim
  properties: {
    path: '/${apiName}'
    apiType: 'http'
    displayName: '${apiName} API'
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'apiKey'
      query: 'apiKey'
    }
    protocols: [
      'http'
      'https'
    ]
  }
}

resource associateAPItoLocalGateway 'Microsoft.ApiManagement/service/gateways/apis@2021-08-01' = {
  name: apiFullName
  parent: gateway
  properties: {}
  dependsOn:[
    facadeApi
  ]
}

resource throttlingPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-08-01' = {
  name: 'policy'
  parent: facadeApi
  properties: {
    value: '<policies><inbound><base /><rate-limit-by-key calls="60" renewal-period="60" counter-key="@(String.Concat("success_", context.Request.IpAddress))" increment-condition="@(context.Response.StatusCode >= 200 && context.Response.StatusCode < 300)" /><rate-limit-by-key calls="20" renewal-period="60" counter-key="@(String.Concat("fail_", context.Request.IpAddress))" increment-condition="@(context.Response.StatusCode >= 400)" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
    format: 'rawxml'
  }
}

resource nvAppInsightsKey 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = if (enableAppInsights) {
  name: 'appinsights-key'
  parent: apim
  properties: {
    tags: []
    secret: true
    displayName: 'appinsights-key'
    value: appInsightsKey
  }
}

resource loggerAppInsights 'Microsoft.ApiManagement/service/loggers@2022-08-01' = if (enableAppInsights) {
  name: 'applicationinsights'
  parent: apim
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights instance dedicated to APIM logging'
    resourceId: appInsightsResourceId
    credentials: {
      instrumentationKey: '{{ appinsights-key }}'
    }
  }
  dependsOn:  [
    nvAppInsightsKey
  ]
}

resource facadeApiMonitoring 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = if (enableAppInsights) {
  name: 'applicationinsights'
  parent: facadeApi
  properties: {
    alwaysLog: 'allErrors'
    loggerId: loggerAppInsights.id  
    logClientIp: true
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    operationNameFormat: 'Url'
  }
}
