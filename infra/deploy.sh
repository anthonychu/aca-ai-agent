# set the following environment variables
# STORAGE_ACCOUNT_NAME

# upload sample-data/foo.pdf to share
az storage file upload --account-name $STORAGE_ACCOUNT_NAME --share-name pdfs --source sample-data/contoso-roles.pdf --path contoso-roles.pdf
az storage file upload --account-name $STORAGE_ACCOUNT_NAME --share-name pdfs --source sample-data/employee_handbook.pdf --path employee_handbook.pdf

az acr build -r $ACR_NAME -t chat-app:1.0 .

az containerapp update -n chat-app -g $RESOURCE_GROUP_NAME --image "$ACR_NAME.azurecr.io/chat-app:1.0"
az containerapp job update -n indexer-job -g $RESOURCE_GROUP_NAME --image "$ACR_NAME.azurecr.io/chat-app:1.0" --args "indexer_job"