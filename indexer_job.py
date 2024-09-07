import os
import time

from langchain_community.document_loaders.pdf import PyMuPDFLoader
from langchain_text_splitters import CharacterTextSplitter

from common import vector_store

dir = os.environ.get("PDF_DIR", os.path.join(os.path.dirname(__file__), "sample-data"))

text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=50)

for pdf_file_name in os.listdir(dir):
    if not pdf_file_name.lower().endswith(".pdf"):
        print(f"Skipping {pdf_file_name} because it is not a PDF file")
        continue

    pdf_file_path = os.path.join(dir, pdf_file_name)
    print(f"Loading and splitting {pdf_file_path}...")

    loader = PyMuPDFLoader(file_path=pdf_file_path)
    docs = loader.load_and_split(text_splitter=text_splitter)

    print(f"{pdf_file_path}: {len(docs)}")

    print("Deleting existing documents for file...")
    existing_docs = vector_store.client.search(filter=f"source eq '{pdf_file_path}'", select="id")
    existing_doc_ids = [doc["id"] for doc in existing_docs]
    vector_store.delete(existing_doc_ids)
    print(f"Deleted {len(existing_doc_ids)} documents")

    print("Adding new documents for file...")
    start_time = time.time()

    vector_store.add_documents(documents=docs)

    time_taken = time.time() - start_time
    print(f"Added {len(docs)} documents in {time_taken:.2f} seconds")

    print("Done!")