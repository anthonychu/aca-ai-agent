param sessionPoolName string
param chatApp object

resource sessionPool 'Microsoft.App/sessionPools@2024-02-02-preview' existing = {
  name: sessionPoolName
}

var sessionExecutorRoleId = '0fb8eba5-a2bb-4abe-b1c1-49dfad359bb0'
resource sessionExecutorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sessionPool.id, sessionExecutorRoleId, resourceGroup().id, 'chatapp')
  scope: sessionPool
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', sessionExecutorRoleId)
    principalId: chatApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
