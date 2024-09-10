param jobName string = 'indexer-job'

resource existingIndexerJob 'Microsoft.App/jobs@2024-02-02-preview' existing = {
  name: jobName
}

output existingIndexerJob object = existingIndexerJob
