#!/bin/bash
. ./variables.sh

echo "${DBG}... Login"
az login --tenant 7517bc42-bcf8-4916-a677-b5753051f846

echo "${DBG}... Set subscription"
az account set --subscription c1537527-c126-428d-8f72-1ac9f2c63c1f


#############################

projectName='holatest'

#############################

echo "${DBG}... Trigger INFRA deployment on $projectName"

RESULT=$(az stack sub create --name $projectName \
    --template-file dtest.bicep \
    --parameters project='holafay' \
    --location westeurope \
    --deny-settings-mode None --yes)

echo "${DBG}..."

echo $RESULT

echo "${DBG}..."
echo "${DBG}... Script completed"
