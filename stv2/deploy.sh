#!/bin/bash
. ./variables.sh

echo "${DBG}... Login"
#az login --tenant 7517bc42-bcf8-4916-a677-b5753051f846

echo "${DBG}... Set subscription"
#az account set --subscription c1537527-c126-428d-8f72-1ac9f2c63c1f

rgName="rg-migrate-to-stv2-plat"

echo "${DBG}... Deploy APIM BASIC on "

# classic
# "apiVersion": "2021-08-01"
# "apiVersion": "2022-09-01-preview"

# V2
# "apiVersion": "2023-03-01-preview, 2023-05-01-preview, 2023-09-01-preview"" 


#RESULT=$(az deployment group create --resource-group $rgName --template-file apim-basic-v2.bicep )

#echo $RESULT

RESULT=$(az deployment group create --resource-group $rgName --template-file apim-basic.bicep )

echo $RESULT


echo "${DBG}... Script completed"
