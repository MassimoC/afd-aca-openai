#!/bin/bash
. ./variables.sh

echo "${DBG}... Login"
#az login --tenant 7517bc42-bcf8-4916-a677-b5753051f846

echo "${DBG}... Set subscription"
#az account set --subscription c1537527-c126-428d-8f72-1ac9f2c63c1f


#############################

projectName='holafay'

#############################

az bicep build --file deploy-infra.bicep 

if [ $? -eq 0 ]; then
  echo "... ... az bicep build succeeded."
else
  echo "... ... az bicep build failed."
  exit
fi

echo "${DBG}... Trigger INFRA deployment on $projectName"

RESULT=$(az stack sub create --name $projectName \
    --template-file deploy-infra.bicep \
    --parameters project=$projectName customDomainSuffix='apifirst.cloud' \
    --location westeurope \
    --deny-settings-mode None --yes)

echo $RESULT

RG=$(echo $RESULT | jq -r '.outputs.rgName.value')
PLS_NAME=$(echo $RESULT | jq -r '.outputs.plsName.value')

echo "${DBG}... Get private endpoint connection for  $PLS_NAME"
PE_CONNECTION=$(az network private-link-service show --name $PLS_NAME --resource-group $RG | jq -r '.privateEndpointConnections[0].id')

echo "${DBG}... Approve private endpoint connection  $PE_CONNECTION"
az network private-endpoint-connection approve --id $PE_CONNECTION --description "Connection to frontdoor approved"

# TODO : second connection has to be approved!!!

echo "${DBG}... Script completed"
