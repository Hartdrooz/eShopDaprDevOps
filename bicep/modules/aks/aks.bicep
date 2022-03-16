param location string
param subnetId string
param aadAdminGroupId string
param aksAzureCniSettings object
param identityAKS object
param workspaceId string

param systemPoolNodeCount int
param workloadNodeCount int

var kubernetesVersion = '1.22.6'
var aksName = 'aksdevops'

resource aks 'Microsoft.ContainerService/managedClusters@2021-10-01' = {
  name: aksName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: identityAKS
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: true
    dnsPrefix: aksName
    agentPoolProfiles: [
      {
        name: 'systempool'
        osDiskSizeGB: 0
        count: systemPoolNodeCount
        enableAutoScaling: false
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'        
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        maxPods: 110
        availabilityZones: null
        vnetSubnetID: subnetId
      }
      {
        name: 'workloadpool'
        osDiskSizeGB: 0
        count: workloadNodeCount
        enableAutoScaling: true
        minCount: 1
        maxCount: 5
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'        
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        maxPods: 110
        availabilityZones: null
        nodeTaints: [
          'type=workload:NoSchedule'
        ]
        vnetSubnetID: subnetId
      }      
    ]
    networkProfile: {
      loadBalancerSku: 'standard'
      networkPlugin: 'azure'
      networkPolicy: 'calico'
      serviceCidr: aksAzureCniSettings.serviceCidr
      dnsServiceIP: aksAzureCniSettings.dnsServiceIP
      dockerBridgeCidr: aksAzureCniSettings.dockerBridgeCidr
    }
    aadProfile: {
      adminGroupObjectIDs: [
        aadAdminGroupId
      ]
      enableAzureRBAC: true
      managed: true
      tenantID: subscription().tenantId
    }
    apiServerAccessProfile: {
      enablePrivateCluster: true
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
      }
      omsagent: {
        config: {
          logAnalyticsWorkspaceResourceID: workspaceId
        }
        enabled: true
      }
    }
  }
}

output clusterName string = aks.name
