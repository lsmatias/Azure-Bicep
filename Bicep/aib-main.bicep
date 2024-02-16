targetScope = 'subscription'
param location string = 'westeurope'
param subscriptionID string = '<YOUR_SUBSCRIPTION_ID>'
param baseTime string = utcNow()

param tags object = {
  Project: 'Automate-AIB-Deployment'
  Responsible: 'Mark Multiverse'
}
param RGnameAVDimage string = 'RG-image'
param RGnameAIB string = 'RG-temp'
param azureImageBuilderName string = 'myImageTemplate'
param runOutputName string = 'Win11test'
param galleryName string = 'myGallery'
param galleryImageName string = 'myGalleryImage'

// Create resource groups
module resourcegroups 'aib-rgs.bicep' = {
  name: 'resources-groups-deployment'
  params: {
    RGnameAIB: RGnameAIB
    RGnameAVDimage: RGnameAVDimage 
    location: location
    tags: tags
  }
}

// Create UAMI, custom role and assign them (on image resource group)
module role 'aib-role.bicep' = {
  scope: resourceGroup(RGnameAVDimage)
  name: 'ID-and-role-deployment'
  params: {
    location: location
    baseTime: baseTime
  }
}

// Assign UAMI and costum role on temporary resource group
module temprole 'aib-roletemp.bicep' = {
  scope: resourceGroup(RGnameAIB)
  name: 'Temporary-AIB-deployment'
  params: {
    subscriptionID: subscriptionID
    RGnameAIB: RGnameAIB
    RGnameAVDimage:RGnameAVDimage
    idName: role.outputs.idName
    baseTime: baseTime
  }
}

// Create Azure Compute Gallery, image and build the image
module image 'aib-image.bicep' = {
  scope: resourceGroup(RGnameAVDimage)
  name: 'image-deployment'
  params: {
    location: location
    RGnameAIB: RGnameAIB
    galleryName: galleryName
    subscriptionID: subscriptionID
    galleryImageName: galleryImageName
    RGnameAVDimage: RGnameAVDimage
    azureImageBuilderName: azureImageBuilderName
    runOutputName: runOutputName
    idNameid: role.outputs.idNameID
  }
}
