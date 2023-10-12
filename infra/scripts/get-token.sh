GW_URI="https://management.azure.com/subscriptions/${sid}/resourceGroups/${rgName}/providers/Microsoft.ApiManagement/service/${apimName}/gateways/${gwName}/generateToken/?api-version=2022-08-01"
GW_TOKEN=$(az rest --method POST --uri "${GW_URI}" --body "{ \"expiry\": \"${expiryDate}\", \"keyType\": \"primary\" }" | jq .value | tr -d "\"")
GW_TOKEN="GatewayKey ${GW_TOKEN}"
echo $(jq --null-input --arg myToken "$GW_TOKEN" '{"ApimToken": $myToken }') > $AZ_SCRIPTS_OUTPUT_PATH