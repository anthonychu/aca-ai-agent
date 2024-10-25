$ErrorActionPreference = "SilentlyContinue"

$RESOURCE_GROUP_NAME = "ResourceGroup1"

$USER_NAME = az account show -o tsv --query user.name

# create role assignments for the lab
$SEARCH_SERVICE_ID = az search service list -g $RESOURCE_GROUP_NAME -o tsv --query [0].id
az role assignment create --role "Search Service Contributor" --assignee $USER_NAME --scope $SEARCH_SERVICE_ID -o json
az role assignment create --role "Search Index Data Contributor" --assignee $USER_NAME --scope $SEARCH_SERVICE_ID -o json

$SESSION_POOL_ID = az containerapp sessionpool list -g $RESOURCE_GROUP_NAME -o tsv --query [0].id
az role assignment create --role "Azure ContainerApps Session Executor" --assignee $USER_NAME --scope $SESSION_POOL_ID -o json

$AZURE_OPENAI_ID = az cognitiveservices account list -g $RESOURCE_GROUP_NAME -o tsv --query [0].id
az role assignment create --role "Cognitive Services OpenAI User" --assignee $USER_NAME --scope $AZURE_OPENAI_ID -o json