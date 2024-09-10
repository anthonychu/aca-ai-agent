param envId string
param acrServer string
param searchEndpoint string
param openAIEndpoint string

// Use a tag to track the creation of the resource
var tagName = 'indexerJobExists'
var indexerJobExists = contains(resourceGroup().tags, tagName) && resourceGroup().tags[tagName] == 'true'

var jobName = 'indexer-job'

// resource existingIndexerJob 'Microsoft.App/jobs@2024-02-02-preview' existing = if (indexerJobExists) {
//   name: jobName
// }

module existingIndexerJob 'existing-job.bicep' = if (indexerJobExists) {
  name: 'existing-indexer-job'
  params: {
    jobName: jobName
  }
}

var containerImage = indexerJobExists ? existingIndexerJob.outputs.existingIndexerJob.properties.template.containers[0].image : 'mcr.microsoft.com/k8se/quickstart-jobs:latest'
// var args = indexerJobExists ? existingIndexerJob.outputs.existingIndexerJob.properties.template.containers[0].args : []

resource indexerJob 'Microsoft.App/jobs@2024-02-02-preview' = {
  name: jobName
  location: resourceGroup().location
  properties: {
    environmentId: envId
    workloadProfileName: 'Consumption'
    configuration: {
      triggerType: 'Schedule'
      replicaTimeout: 1800
      replicaRetryLimit: 0
      scheduleTriggerConfig: {
        replicaCompletionCount: 1
        cronExpression: '*/5 * * * *'
        parallelism: 1
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
          name: 'job'
          args: [
            'indexer_job'
          ]
          env: [
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: openAIEndpoint
            }
            {
              name: 'AZURE_SEARCH_ENDPOINT'
              value: searchEndpoint
            }
          ]
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          volumeMounts: [
            {
              volumeName: 'pdfs'
              mountPath: '/app/sample-data'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'pdfs'
          storageType: 'AzureFile'
          storageName: 'pdfs'
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource tags 'Microsoft.Resources/tags@2024-03-01' = {
  name: 'default'
  properties: {
    tags: {
      '${tagName}': 'true'
    }
  }
  dependsOn: [
    indexerJob
  ]
}


output indexerJob object = indexerJob
