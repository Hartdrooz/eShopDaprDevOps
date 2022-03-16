param vnetId string
param vnetName string
param location string
param subnetId string
param privateLinkResourceId string
param runnerVms array

var privateEndpointName = 'pe-acr'

resource privateAcrDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
}

resource aRecordJumpbox 'Microsoft.Network/privateDnsZones/A@2020-06-01' = [for runner in runnerVms: {
  name: '${privateAcrDnsZone.name}/${runner.jumpboxname}'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: runner.jumpboxPrivateIP
      }
    ]
  }
}]

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${privateAcrDnsZone.name}/link_to_${toLower(vnetName)}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: privateLinkResourceId
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

resource privateDNSZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: '${privateEndpoint.name}/default' 
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurecr-io'
        properties: {
          privateDnsZoneId: privateAcrDnsZone.id
        }
      }
    ]
  } 
}


