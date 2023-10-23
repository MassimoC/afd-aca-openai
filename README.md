# Azure Open AI Lab


# Resources

This test lab implement / uses / is inspired by the following articles and examples :
* https://techcommunity.microsoft.com/t5/azure-architecture-blog/building-a-private-chatgpt-interface-with-azure-openai/ba-p/3869522
* https://github.com/pascalvanderheiden/ais-apim-openai


# Architecture



## Test from ACI

```
curl https://ai-holaday.openai.azure.com/ -iv

curl http://app-01--tnsnrrp.yellowstone-32fc685b.westeurope.azurecontainerapps.io/ -iv

curl https://apim-holafay.azure-api.net/status-0123456789abcdef -iv

# completions (open ai private endpoint)
curl https://ai-holafay.openai.azure.com/openai/deployments/gptholafay/completions?api-version=2023-05-15 -H "Content-Type: application/json" -H "api-key: 2af3ea4065dd492c820c6ae8df65705b" -d "{\"prompt\": \"Once upon a time\", \"max_tokens\": 5}"

# chat/completions (open ai private endpoint)
curl https://ai-holafay.openai.azure.com/openai/deployments/gptholafay/chat/completions?api-version=2023-05-15 -H "Content-Type: application/json" -H "api-key: 2af3ea4065dd492c820c6ae8df65705b" -d "{\"model\": \"gpt-35-turbo\",\"messages\": [{\"role\": \"user\",\"content\": \"What API means for you?\"}]}"

# chat/completions (via APIM internal)
curl https://apim-holafay.azure-api.net/openai/deployments/gptholafay/chat/completions?api-version=2023-05-15 -H "Content-Type: application/json" -H "api-key: 2af3ea4065dd492c820c6ae8df65705b" -H "package-key: 875ea2746ea942a8afaeaca284b8c138"  -d "{\"model\": \"gpt-35-turbo\",\"messages\": [{\"role\": \"user\",\"content\": \"What API means for you?\"}]}"

# chat/completions (via afd, APIM gateway on ACA)
curl https://lab3.apifirst.cloud/openai/deployments/gptholafay/chat/completions?api-version=2023-05-15 -H "Content-Type: application/json" -H "api-key: 2af3ea4065dd492c820c6ae8df65705b" -H "package-key: 875ea2746ea942a8afaeaca284b8c138"  -d "{\"model\": \"gpt-35-turbo\",\"messages\": [{\"role\": \"user\",\"content\": \"What API means for you?\"}]}"

```


## Restart APIM

```
https://docs.microsoft.com/en-us/rest/api/apimanagement/current-ga/api-management-service/apply-network-configuration-updates
```

## Chatbot UI

```
# Tag
docker build -t chatgpt-ui .

docker tag chatgpt-ui:latest holafay.azurecr.io/chatgpt-ui:1.0.6

# Login
az acr login --name holafay

# Push
docker push holafay.azurecr.io/chatgpt-ui:1.0.6

az acr repository list --name holafay -o table

```

```
docker login -u massimocrippa -p yeahsure
docker tag chatgpt-ui:1.0.6 massimocrippa/chatgpt-ui:1.0.6
docker push massimocrippa/chatgpt-ui:1.0.6
```