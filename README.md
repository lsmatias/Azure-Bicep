# Automatize o Azure Image Builder no Bicep com custom builder resource group

Com o Azure Image Builder (AIB), podemos automatizar o processo de construção de imagens para uso em um ambiente Azure Virtual Desktop, por exemplo. AIB cria automaticamente um grupo de recursos para armazenar recursos temporários necessários para construir a imagem (conta de armazenamento, vnet, vm, disco, etc.). Quando a construção é concluída, o Azure exclui a maioria desses recursos. Este grupo de recursos de construção recebe um nome aleatório que começa com IT_. Quando você tem políticas em vigor que exigem uma determinada convenção de nomenclatura ou exigem determinadas tags em um grupo de recursos, a construção do AIB falhará. Mas felizmente há uma maneira de garantir que o grupo de recursos utilize a convenção de nomenclatura e as tags corretas.

Então, em geral, este blog aborda dois aspectos:

Automatizar o AIB em Bicep
Personalizar o grupo de recursos de construção para o AIB
Passos
Passos envolvidos:

Criar grupos de recursos
Criar identidade gerenciada atribuída pelo usuário
Criar função personalizada
Atribuir a função personalizada à identidade gerenciada
Criar Azure Compute Gallery
Criar Imagem da Galeria
Criar Modelo de Imagem
Construir Modelo de Imagem
Visão Geral
Neste exemplo, todos os grupos de recursos devem começar com RG- e exigir as tags Projeto e Responsável.

Os arquivos Bicep completos podem ser encontrados no meu repositório GitHub aqui. A automação contém cinco arquivos Bicep:

aib-main.bicep

aib-rgs.bicep

aib-role.bicep

aib-roletemp.bicep

aib-image.bicep

Esta implantação resulta nos seguintes recursos no Azure:

<img width="618" alt="image" src="https://github.com/lsmatias/Azure-Bicep/assets/28391885/49633279-a831-430e-be7a-aa520c381b40">

O arquivo Bicep principal
Este é o arquivo Bicep principal que será implantado no Azure.
Por favor, esteja ciente de que você precisa alterar o valor subscriptionID com o ID da sua assinatura Azure.

<img width="20" alt="image" src="https://github.com/lsmatias/Azure-Bicep/assets/28391885/7556e2b2-0b22-4a2b-a40c-3175301d7357">
Bicep

```
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
```

Existem quatro módulos invocados pelo arquivo. Com os parâmetros tags e RGnameAIB, podemos nos conformar à Política do Azure que define o nome do grupo de recursos e as tags obrigatórias.

# Criando Resource Group

A criação dos grupos de recursos é feita no arquivo aib-rgs.bicep.

<img width="20" alt="image" src="https://github.com/lsmatias/Azure-Bicep/assets/28391885/7556e2b2-0b22-4a2b-a40c-3175301d7357">
Bicep

```
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
```

Criando a Identidade Gerenciada e a Função Personalizada
Nós utilizamos a mesma identidade gerenciada para acessar os dois grupos de recursos e construir a imagem.



