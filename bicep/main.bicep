@description('The location where the Azure resources will be deployed')
param location string

@description('The settings of the virtual network')
param vnetSettings object

@description('The number of node count in the system pool')
param systemPoolNodeCount int

@description('The number of node count in the workload pool')
param workloadNodeCount int

@description('The username of the admin of the VM')
@secure()
param adminUsername string

@description('The admin password to connect to the VM')
@secure()
param adminPassword string

@description('The version of Ubuntu OS')
param ubuntuVersion string

@description('The size of the VM')
param vmSize string

@description('The objectID in Azure AD of the AKS Admin Group')
param aadAdminGroupId string

@description('The setting for the AzureCNI networking')
param aksAzureCniSettings object

@description('Switch if you are not running the data storage locally in the AKS cluster')
param azureResourceSwitch bool = false

var suffix = uniqueString(resourceGroup().id)
var aksInfraResourceGroupName =  'MC_${resourceGroup().name}_${aks.outputs.clusterName}_${location}'
var networkContributorRoleId = resourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')

module vnet 'modules/network/vnet.bicep' = {
  name: 'vnet'
  params: {
    location: location 
    suffix: suffix
    vnetSettings: vnetSettings    
  }
}

module acr 'modules/acr/registry.bicep' = {
  name: 'acr'
  params: {
    location: location
    suffix: suffix
  }
}

module selfRunners 'modules/compute/linux.bicep' = {
  name: 'selfRunners'
  params: {
    location: location    
    subnetId: vnet.outputs.jumpboxSubnetId
    adminPassword: adminPassword
    adminUsername: adminUsername
    ubuntuVersion: ubuntuVersion
    vmSize: vmSize    
  }
}

module privateZoneAcr 'modules/dns/privateACRDnzZone.bicep' = {
  name: 'privateZoneAcr'
  params: {
    location: location
    vnetName: vnet.outputs.virtualNetworkName
    privateLinkResourceId: acr.outputs.acrId
    subnetId: vnet.outputs.prvEndpointSubnetId
    vnetId: vnet.outputs.vnetId
    runnerVms: selfRunners.outputs.runnerVmInfo
  }
}

module storage 'modules/storage/storage.bicep' = if (azureResourceSwitch) {
  name: 'storage'
  params: {
    location: location
    suffix: suffix
  }
}

module workspace 'modules/workspace/workspace.bicep' = {
  name: 'workspace'
  params: {
    location: location
    suffix: suffix
  }
}

module identityAks 'modules/identity/userassigned.identity.bicep' = {
  name: 'identityAks'
  params: {
    location: location
    name: 'aks-identity'
  }
}

module networkContributorRole 'modules/identity/role.bicep' = {
  name: 'networkContributorRole'
  params: {
    principalId: identityAks.outputs.principalId
    roleGuid: networkContributorRoleId
    vnetName: vnet.outputs.virtualNetworkName
    subnetName: vnet.outputs.aksSubnetName
  }
}

module aks 'modules/aks/aks.bicep' = {
  name: 'aks'
  dependsOn: [
    networkContributorRole
  ]
  params: {
    aadAdminGroupId: aadAdminGroupId
    aksAzureCniSettings: aksAzureCniSettings
    location: location
    subnetId: vnet.outputs.aksSubnetId
    identityAKS: {
      '${identityAks.outputs.identityId}': {}
    }
    workspaceId: workspace.outputs.workSpaceId
    systemPoolNodeCount: systemPoolNodeCount
    workloadNodeCount: workloadNodeCount
  }
}

module redis 'modules/redis/redis.bicep' = if (azureResourceSwitch) {
  name: 'redis'
  params: {
    location: location
    suffix: suffix
  }
}

module servicebus 'modules/servicebus/servicebus.bicep' = if (azureResourceSwitch) {
  name: 'servicebus'
  params: {
    location: location
    suffix: suffix
  }
}

// module sql 'modules/sql/sql.bicep' = if (azureResourceSwitch) {
//   name: 'sql'
//   params: {
//     administratorLogin: adminSqlUsername
//     administratorLoginPassword: adminSqlPassword
//     location: location
//   }
// }

output arcName string = acr.outputs.acrName
output aksRgName string = aksInfraResourceGroupName
output aksName string = aks.outputs.clusterName
output acrShortName string = acr.outputs.acrShortName
