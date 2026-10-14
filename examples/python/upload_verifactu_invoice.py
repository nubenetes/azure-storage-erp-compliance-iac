#!/usr/bin/env python3
"""
upload_verifactu_invoice.py
Sample ERP Integration: Uploads an invoice PDF with VeriFactu metadata and tags,
and demonstrates querying and rehydration from the Archive tier.
"""

import os
import sys
from datetime import datetime

# Requires: pip install azure-storage-blob azure-identity
try:
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import BlobServiceClient, RehydratePriority
except ImportError:
    print("Dependencies missing. Run: pip install azure-storage-blob azure-identity")
    sys.exit(0)

def upload_invoice(
    account_name: str,
    container_name: str,
    invoice_path: str,
    invoice_number: str,
    fiscal_year: str,
    customer_tax_id: str,
    chain_hash: str,
):
    account_url = f"https://{account_name}.blob.core.windows.net"
    credential = DefaultAzureCredential()
    blob_service_client = BlobServiceClient(account_url=account_url, credential=credential)
    container_client = blob_service_client.get_container_client(container_name)

    blob_name = f"{fiscal_year}/{invoice_number}.pdf"
    blob_client = container_client.get_blob_client(blob_name)

    # 1. Metadata (Key-Value string attributes)
    metadata = {
        "invoice_number": invoice_number,
        "fiscal_year": fiscal_year,
        "customer_tax_id": customer_tax_id,
        "verifactu_hash": chain_hash,
        "uploaded_at": datetime.utcnow().isoformat(),
        "compliance": "CodigoDeComercioArt30_VeriFactu",
    }

    # 2. Blob Index Tags (Searchable without scanning all blobs)
    tags = {
        "InvoiceNumber": invoice_number.replace("-", "_"),
        "FiscalYear": fiscal_year,
        "CustomerTaxID": customer_tax_id,
        "Status": "CommittedWORM",
    }

    print(f"Uploading invoice '{blob_name}' to container '{container_name}'...")
    with open(invoice_path, "rb") as data:
        blob_client.upload_blob(
            data=data,
            overwrite=False, # Immutable storage will reject overwrites anyway
            metadata=metadata,
            tags=tags,
        )
    print(f"✓ Invoice successfully archived in WORM container: {blob_client.url}")

def request_rehydration(account_name: str, container_name: str, blob_name: str, high_priority: bool = False):
    account_url = f"https://{account_name}.blob.core.windows.net"
    credential = DefaultAzureCredential()
    blob_service_client = BlobServiceClient(account_url=account_url, credential=credential)
    blob_client = blob_service_client.get_blob_client(container=container_name, blob=blob_name)

    priority = RehydratePriority.HIGH if high_priority else RehydratePriority.STANDARD
    print(f"Requesting rehydration of '{blob_name}' to Cool tier with priority '{priority}'...")
    blob_client.set_blob_tier(tier="Cool", rehydrate_priority=priority)
    print("✓ Rehydration initiated. The blob will be readable once background rehydration completes.")

if __name__ == "__main__":
    print("This is a reference code sample demonstrating ERP integration.")
    print("See docs/ERP_INTEGRATION_AND_REHYDRATION.md for full architectural details.")
