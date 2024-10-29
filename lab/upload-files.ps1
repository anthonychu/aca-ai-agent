$ErrorActionPreference = "SilentlyContinue"

$RESOURCE_GROUP_NAME = "ResourceGroup1"
$PDF_PATH = $PSScriptRoot + '\..\more-pdfs\azure-container-apps-docs.pdf'

$STORAGE_ACCOUNT_NAME = az storage account list -g $RESOURCE_GROUP_NAME -o tsv --query [0].name
az storage file upload --account-name $STORAGE_ACCOUNT_NAME --share-name pdfs --source $PDF_PATH --path azure-container-apps-docs.pdf
