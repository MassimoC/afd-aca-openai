# afd-aca-openai


## Test from ACI

```
curl https://ai-holaday.openai.azure.com/ -iv

curl http://app-01--tnsnrrp.yellowstone-32fc685b.westeurope.azurecontainerapps.io/ -iv

# completions
curl https://ai-holafay.openai.azure.com/openai/deployments/gptholafay/completions?api-version=2023-05-15 -H "Content-Type: application/json" -H "api-key: 2af3ea4065dd492c820c6ae8df65705b" -d "{\"prompt\": \"Once upon a time\", \"max_tokens\": 5}"

# chat/completions
curl https://ai-holafay.openai.azure.com/openai/deployments/gptholafay/chat/completions?api-version=2023-05-15 -H "Content-Type: application/json" -H "api-key: 2af3ea4065dd492c820c6ae8df65705b" -d "{\"model\": \"gpt-35-turbo\",\"messages\": [{\"role\": \"user\",\"content\": \"What API means for you?\"}]}"

```

## Restart APIM

```
https://docs.microsoft.com/en-us/rest/api/apimanagement/current-ga/api-management-service/apply-network-configuration-updates
```