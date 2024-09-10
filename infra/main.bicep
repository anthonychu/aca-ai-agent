targetScope = 'resourceGroup'

var openAIAccountName = 'openai-${uniqueString(resourceGroup().id)}'
var azureOpenAIRegion = 'canadaeast'

var searchServiceName = 'search-${uniqueString(resourceGroup().id)}'
var acrName = 'acr${uniqueString(resourceGroup().id)}'
var logAnalyticsWorkspaceName = 'loganalytics-${uniqueString(resourceGroup().id)}'
var acaEnvName = 'env-${uniqueString(resourceGroup().id)}'
var sessionPoolName = 'sessionpool-${uniqueString(resourceGroup().id)}'
var storageAccountName = 'acastorage${uniqueString(resourceGroup().id)}'

resource openAIAccount 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: openAIAccountName
  location: azureOpenAIRegion
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    publicNetworkAccess: 'Enabled'
    customSubDomainName: openAIAccountName
  }
}

resource ada002 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: openAIAccount
  name: 'text-embedding-ada-002'
  sku: {
    name: 'Standard'
    capacity: 150
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 150
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

resource gpt35turbo 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: openAIAccount
  name: 'gpt-35-turbo'
  sku: {
    name: 'Standard'
    capacity: 100
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-35-turbo'
      version: '1106'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 100
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}


resource aiSearch 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: searchServiceName
  location: resourceGroup().location
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'Enabled'
    networkRuleSet: {
      ipRules: []
      bypass: 'None'
    }
    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    disabledDataExfiltrationOptions: []
    semanticSearch: 'free'
  }
  sku: {
    name: 'basic'
  }
}



resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  sku: {
    name: 'Standard'
  }
  name: acrName
  location: resourceGroup().location
  tags: {}
  properties: {
    adminUserEnabled: false
    policies: {
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    anonymousPullEnabled: false
    metadataSearch: 'Enabled'
  }
}


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: resourceGroup().location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'

  resource fileService 'fileServices@2023-05-01' = {
    name: 'default'
    resource share 'shares@2023-05-01' = {
      name: 'pdfs'
      properties: {
        enabledProtocols: 'SMB'
        accessTier: 'TransactionOptimized'
        shareQuota: 1024
      }
    }
  }
}


resource env 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: acaEnvName
  location: resourceGroup().location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
         workloadProfileType: 'Consumption'
      }
    ]
  }
  identity: {
    type: 'SystemAssigned'
  }

  resource storages 'storages@2024-02-02-preview' = {
    name: 'pdfs'
    properties: {
      azureFile: {
        shareName: 'pdfs'
        accountName: storageAccount.name
        accountKey: storageAccount.listKeys().keys[0].value
        accessMode: 'ReadWrite'
      }
    }
  }
}

var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, acrPullRoleId, env.id)
  scope: registry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: env.identity.principalId
    principalType: 'ServicePrincipal'
  }
}


resource sessionPool 'Microsoft.App/sessionPools@2024-02-02-preview' = {
  name: sessionPoolName
  location: 'North Central US'
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


module chatApp 'container-app.bicep' = {
  name: 'container-app'
  params: {
    envId: env.id
    searchEndpoint: 'https://${aiSearch.name}.search.windows.net'
    openAIEndpoint: openAIAccount.properties.endpoint
    sessionPoolEndpoint: sessionPool.properties.poolManagementEndpoint
    acrServer: registry.properties.loginServer
  }
}

var sessionExecutorRoleId = '0fb8eba5-a2bb-4abe-b1c1-49dfad359bb0'
resource sessionExecutorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sessionPool.id, sessionExecutorRoleId, resourceGroup().id, 'chatapp')
  scope: sessionPool
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sessionExecutorRoleId)
    principalId: chatApp.outputs.chatApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

var searchIndexDataContributorRoleId = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
resource appSearchIndexDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearch.id, searchIndexDataContributorRoleId, resourceGroup().id, 'chatapp')
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: chatApp.outputs.chatApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

var searchServiceContributorRoleId = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
resource appSearchServiceContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearch.id, searchServiceContributorRoleId, resourceGroup().id, 'chatapp')
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRoleId)
    principalId: chatApp.outputs.chatApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

var openAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
resource appOpenAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAIAccount.id, openAIUserRoleId, resourceGroup().id, 'chatapp')
  scope: openAIAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', openAIUserRoleId)
    principalId: chatApp.outputs.chatApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}


module indexerJob 'container-job.bicep' = {
  name: 'indexer-job'
  params: {
    envId: env.id
    acrServer: registry.properties.loginServer
    openAIEndpoint: openAIAccount.properties.endpoint
    searchEndpoint: 'https://${aiSearch.name}.search.windows.net'
  }
}

resource jobSearchIndexDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearch.id, searchIndexDataContributorRoleId, resourceGroup().id, 'indexerjob')
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: indexerJob.outputs.indexerJob.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource jobSearchServiceContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearch.id, searchServiceContributorRoleId, resourceGroup().id, 'indexerjob')
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRoleId)
    principalId: indexerJob.outputs.indexerJob.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource jobOpenAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAIAccount.id, openAIUserRoleId, resourceGroup().id, 'indexerjob')
  scope: openAIAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', openAIUserRoleId)
    principalId: indexerJob.outputs.indexerJob.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output STORAGE_ACCOUNT_NAME string = storageAccount.name
output ACR_NAME string = registry.name
output RESOURCE_GROUP_NAME string = resourceGroup().name
