$ErrorActionPreference = "SilentlyContinue"

$RESOURCE_GROUP_NAME = "ResourceGroup1"

$ENV_FILE_PATH = $PSScriptRoot + '\..\src\.env'

$AZURE_OPENAI_ENDPOINT = az cognitiveservices account list -g $RESOURCE_GROUP_NAME -o tsv --query [0].properties.endpoint
$AZURE_SEARCH_NAME = az search service list -g $RESOURCE_GROUP_NAME -o tsv --query [0].name
$AZURE_SEARCH_ENDPOINT = "https://$AZURE_SEARCH_NAME.search.windows.net"
$POOL_MANAGEMENT_ENDPOINT = az containerapp sessionpool list -g $RESOURCE_GROUP_NAME -o tsv --query [0].properties.poolManagementEndpoint

# write the environment variables to the .env file
@"
POOL_MANAGEMENT_ENDPOINT=$POOL_MANAGEMENT_ENDPOINT
AZURE_SEARCH_ENDPOINT=$AZURE_SEARCH_ENDPOINT
AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT
"@ | Out-File -FilePath $ENV_FILE_PATH -Encoding utf8