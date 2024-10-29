$DATETIME = Get-Date -Format "yyyyMMddHHmmss"
az acr build -r $Env:ACR_NAME -t "chat-app:$DATETIME" src

az containerapp update -n chat-app -g $Env:RESOURCE_GROUP_NAME --image "$Env:ACR_NAME.azurecr.io/chat-app:$DATETIME" --args chat_app
az containerapp job update -n indexer-job -g $Env:RESOURCE_GROUP_NAME --image "$Env:ACR_NAME.azurecr.io/chat-app:$DATETIME" --args indexer_job