param name string 
param subnetId string
param location string = resourceGroup().location
param tags object = {}

resource netprofile 'Microsoft.Network/networkProfiles@2020-11-01' = {
  name: 'aci-net-profile'
  location: location
  properties:{
    containerNetworkInterfaceConfigurations:[
      {
        name : 'aci-container-nic'
        properties:{
          ipConfigurations:[
            {
              name: 'aci-ip-config-profile'
              properties:{
                subnet:{
                  id: subnetId
                }
              }
            }
          ]
        }
      }
    ]
  }
}

resource aci 'Microsoft.ContainerInstance/containerGroups@2021-03-01' = {
  name: name
  location: location
  tags: tags
  properties:{
    restartPolicy:'Never'
    osType:'Linux'
    networkProfile:{
      id: netprofile.id
    }
    containers:[
      {
        name:name
        properties:{
          image: 'curlimages/curl'
          command:[
            'tail'
            '-f'
            '/dev/null'
          ]
         ports:[
           {
             protocol:'TCP'
             port: 80
           }
         ]
         environmentVariables:[
           
         ]
         resources:{
           requests:{
             memoryInGB: 2
             cpu: 1
           }
         }
        }
      }
    ]
  }
}

output aciResourceId string = aci.id
