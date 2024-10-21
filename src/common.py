import os
from langchain_community.vectorstores.azuresearch import AzureSearch
from langchain_openai import AzureOpenAIEmbeddings, OpenAIEmbeddings
from azure.identity import get_bearer_token_provider, DefaultAzureCredential
from azure.search.documents.indexes import SearchIndexClient
from dotenv import load_dotenv

load_dotenv()

from azure.search.documents.indexes.models import (
    ScoringProfile,
    SearchableField,
    SearchField,
    SearchFieldDataType,
    SimpleField,
    TextWeights,
)

azure_endpoint: str = os.environ["AZURE_OPENAI_ENDPOINT"]
azure_openai_api_version: str = "2023-05-15"
azure_deployment: str = "text-embedding-ada-002"

vector_store_address: str = os.environ.get("AZURE_SEARCH_ENDPOINT", "https://anthony.search.windows.net")
vector_store_password: str = None # we'll use managed identity

index_name = os.environ.get("AZURE_SEARCH_INDEX_NAME", 'langchain-azure-search')

credential = DefaultAzureCredential()

embeddings: AzureOpenAIEmbeddings = AzureOpenAIEmbeddings(
    azure_deployment=azure_deployment,
    openai_api_version=azure_openai_api_version,
    azure_endpoint=azure_endpoint,
    azure_ad_token_provider=get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default"),
)

fields = [
    SimpleField(
        name="id",
        type=SearchFieldDataType.String,
        key=True,
        filterable=True,
    ),
    SearchableField(
        name="content",
        type=SearchFieldDataType.String,
        searchable=True,
    ),
    SearchField(
        name="content_vector",
        type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
        searchable=True,
        vector_search_dimensions=len(embeddings.embed_query("Text")),
        vector_search_profile_name="myHnswProfile",
    ),
    SearchableField(
        name="metadata",
        type=SearchFieldDataType.String,
        searchable=True,
    ),
    # Additional field for filtering on document source
    SimpleField(
        name="source",
        type=SearchFieldDataType.String,
        filterable=True,
    ),
]

vector_store: AzureSearch = AzureSearch(
    azure_search_endpoint=vector_store_address,
    azure_search_key=vector_store_password,
    azure_ad_access_token=None,
    index_name=index_name,
    embedding_function=embeddings.embed_query,
    fields=fields,
    # Configure max retries for the Azure client
    additional_search_client_options={
        "retry_total": 4,
        # "credential": credential,
    },
)

search_index_client = SearchIndexClient(endpoint=vector_store_address, credential=credential)
