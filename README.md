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

* aib-main.bicep

* aib-rgs.bicep

* aib-role.bicep

* aib-roletemp.bicep

* aib-image.bicep

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

A criação dos grupos de recursos é feita no arquivo `aib-rgs.bicep`.

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

<img width="420" alt="image" src="https://github.com/lsmatias/Azure-Bicep/assets/28391885/532ed066-46f9-474c-892d-5a4948e33887">


Dentro do arquivo `aib-role.bicep`, criamos a Identidade Gerenciada atribuída pelo usuário e a Função Personalizada.

```
param location string
param baseTime string

var idAIBName = 'AIB${baseTime}'
var roleDefName = 'Azure Image Builder Def ${baseTime}'


// Create a user assigned identity
resource aibId 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
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
```
O valor name dos três recursos criados aqui todos têm variáveis neles. Eu prefiro isso para acompanhar minha implantação de imagem.
`Microsoft.VirtualMachineImages/imageTemplates/run/action` A ação não é necessária para as ações feitas no grupo de recursos RG-image. Mas é necessária para a construção da imagem no RG-temp e eu quero usar a mesma Identidade Gerenciada para isso.

Defina a Função Personalizada no grupo de recursos de construção. No arquivo `aib-roletemp.bicep`, atribuímos a combinação da Identidade Gerenciada e da Função Personalizada ao grupo de recursos de construção (RG-temp).

```
param baseTime string
param subscriptionID string
param RGnameAIB string
param idName string
param RGnameAVDimage string

resource aibId 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
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
```
Criar o Build da imagem.
No recurso `Microsoft.VirtualMachineImages/imageTemplates`, criamos a imagem e podemos personalizá-la para atender às nossas necessidades.

```
param location string
param subscriptionID string
param galleryName string
param azureImageBuilderName string
param galleryImageName string
param runOutputName string
param RGnameAIB string
param RGnameAVDimage string
param idNameid string


resource acg 'Microsoft.Compute/galleries@2022-08-03' = {
  name: galleryName
  location: location
  properties: {
    description: 'mygallery'
  }
}

resource ign 'Microsoft.Compute/galleries/images@2022-08-03' = {
  name: galleryImageName
  location: location
  parent: acg
  properties: {
    identifier: {
      offer: 'windows-11'
      publisher: 'microsoftwindowsdesktop'
      sku: 'win11-23h2-avd'
    }
    osState: 'Generalized' 
    osType: 'Windows'
    hyperVGeneration: 'V2'
  }
}

resource azureImageBuilder 'Microsoft.VirtualMachineImages/imageTemplates@2022-02-14' = {
  name: azureImageBuilderName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: json('{"${idNameid}":{}')
  }
  properties: {
    buildTimeoutInMinutes: 60
    distribute: [
      {
        type: 'SharedImage'
        galleryImageId: ign.id
        runOutputName: runOutputName
        replicationRegions: [
          location
        ]
      }
    ]
    source: {
      type: 'PlatformImage'
      publisher: 'microsoftwindowsdesktop'
      offer:'windows-11'
      sku: 'win11-23h2-avd'
      version: 'latest'
    }
    stagingResourceGroup: '/subscriptions/${subscriptionID}/resourceGroups/${RGnameAIB}'
    vmProfile: {
      vmSize: 'Standard_D2s_v3'
      osDiskSizeGB: 127
    }
    customize: [
      {
        type: 'PowerShell'
        name: 'GetAZCopy'
        inline: [
          'New-Item -Type Directory -Path c:\\ -Name temp'
          'invoke-webrequest -uri https://aka.ms/downloadazcopy-v10-windows -OutFile c:\\temp\\azcopy.zip'
          'Expand-Archive c:\\temp\\azcopy.zip c:\\temp'
          'copy-item C:\\temp\\azcopy_windows_amd64_*\\azcopy.exe\\ -Destination c:\\temp'
        ]
      }
    ]
  }
}

resource buildimage 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'buildimage'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: json('{"${idNameid}":{}')
  }
  properties: {
    azCliVersion: '2.52.0' 
    retentionInterval: 'P1D'
    environmentVariables: [
      {
        name: 'azureImageBuilderName'
        value: azureImageBuilderName
      }
      {
        name: 'RGnameAVDimage'
        value: RGnameAVDimage
      }
    ]
    scriptContent: '''
      az login --identity
      az image builder run -n $azureImageBuilderName -g $RGnameAVDimage --no-wait
    '''
  }
  dependsOn: [
    azureImageBuilder
  ]
}
```

A construção real da imagem é feita no Azure CLI. Eu defini a maior parte da imagem diretamente no código porque torna mais fácil de ler. Em produção, eu faria mais uso de parâmetros.
Para mostrar como as personalizações são feitas, adicionei o AZCopy à imagem. A conta de armazenamento que foi criada automaticamente contém o arquivo de log da construção. Isso é muito útil quando você adiciona mais personalizações do que o AZCopy.
Sinta-se à vontade para experimentar várias personalizações. Isso torna tudo mais divertido!
