param baseTime string
param subscriptionID string
param RGnameAIB string
param idName string
param RGnameAVDimage string

resource aibId 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-07-31-preview' existing = {
  name: idName
  scope: resourceGroup(RGnameAVDimage)
}

resource roleAssignmentAIBrg 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aibId.name, baseTime)
  properties: {
    principalId: aibId.properties.principalId
    roleDefinitionId: '/subscriptions/${subscriptionID}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
    principalType: 'ServicePrincipal'
    scope: '/subscriptions/${subscriptionID}/resourcegroups/${RGnameAIB}'
  }
}
