param envId string
param acrServer string
param searchEndpoint string
param openAIEndpoint string
param sessionPoolEndpoint string
param tagName string
param location string

// Use a tag to track the creation of the resource
var appExists = contains(resourceGroup().tags, tagName) && resourceGroup().tags[tagName] == 'true'

resource existingChatApp 'Microsoft.App/containerApps@2024-02-02-preview' existing = if (appExists) {
  name: 'chat-app'
}

var containerImage = appExists ? existingChatApp.properties.template.containers[0].image : 'mcr.microsoft.com/k8se/quickstart:latest'

resource chatApp 'Microsoft.App/containerApps@2024-02-02-preview' = if (!appExists) {
  name: 'chat-app'
  location: location
  properties: {
    environmentId: envId
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        transport: 'Auto'
        stickySessions: {
          affinity: 'sticky'
        }
      }
      registries: [
        {
          server: acrServer
          identity: 'system-environment'
        }
      ]
    }
    template: {
      containers: [
        {
          image: containerImage
          name: 'main'
          args: [
            'chat_app'
          ]
          env: [
            {
              name: 'AZURE_SEARCH_ENDPOINT'
              value: searchEndpoint
            }
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: openAIEndpoint
            }
            {
              name: 'POOL_MANAGEMENT_ENDPOINT'
              value: sessionPoolEndpoint
            }
          ]
          resources: {
            cpu: 2
            memory: '4Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}


output chatApp object = chatApp
