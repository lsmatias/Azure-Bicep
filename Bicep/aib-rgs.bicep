targetScope = 'subscription'

param location string
// Placing the tags on the resource groups
param tags object 
// Naming the resource groups
param RGnameAVDimage string
param RGnameAIB string

resource RGAVDimage 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: RGnameAVDimage
  location: location
  tags: tags
}

resource RGAVDimagebuild 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: RGnameAIB
  location: location
  tags: tags
}
