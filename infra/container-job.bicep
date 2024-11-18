param envId string
param acrServer string
param searchEndpoint string
param openAIEndpoint string
param tagName string
param location string

// Use a tag to track the creation of the resource
var indexerJobExists = contains(resourceGroup().tags, tagName) && resourceGroup().tags[tagName] == 'true'

var jobName = 'indexer-job'

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
  location: location
  properties: {
    environmentId: envId
    workloadProfileName: 'Consumption'
    configuration: {
      triggerType: 'Schedule'
      replicaTimeout: 1800
      replicaRetryLimit: 0
      scheduleTriggerConfig: {
        replicaCompletionCount: 1
        // every day at 7AM UTC
        cronExpression: '0 7 * * *'
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


output indexerJob object = indexerJob
