param location string
param baseTime string

var idAIBName = 'AIB${baseTime}'
var roleDefName = 'Azure Image Builder Def ${baseTime}'


// Create a user assigned identity
resource aibId 'Microsoft.ManagedIdentity/userAssignedIdentities@sample-preview' = {
  name: idAIBName
  location: location
}

output idName string = aibId.name
output idNameID string = aibId.id

// Create a custom role
resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' = {
  name: guid(resourceGroup().id, 'bicep')
  properties: {
    roleName: roleDefName
    description: 'Image Builder access to create resources for the image build'
    type: 'customRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/galleries/read'
          'Microsoft.Compute/galleries/images/read'
          'Microsoft.Compute/galleries/images/versions/read'
          'Microsoft.Compute/galleries/images/versions/write'
          'Microsoft.Compute/images/write'
          'Microsoft.Compute/images/read'
          'Microsoft.Compute/images/delete'

          'Microsoft.VirtualMachineImages/imageTemplates/run/action'
        ]
        notActions: []
      }
    ]
    assignableScopes: [
      resourceGroup().id
    ]
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aibId.name)
  properties: {
    principalId: aibId.properties.principalId
    roleDefinitionId: roleDef.id
    principalType: 'ServicePrincipal'
  }
}
