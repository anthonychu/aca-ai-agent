param location string
param name string

resource sessionPool 'Microsoft.App/sessionPools@2024-02-02-preview' = {
  name: name
  location: location
  properties: {
    poolManagementType: 'Dynamic'
    containerType: 'PythonLTS'
    scaleConfiguration: {
      maxConcurrentSessions: 50
    }
    dynamicPoolConfiguration: {
      executionType: 'Timed'
      cooldownPeriodInSeconds: 300
    }
    sessionNetworkConfiguration: {
      status: 'EgressDisabled'
    }
  }
}

output sessionPool object = sessionPool
