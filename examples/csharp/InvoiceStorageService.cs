// ------------------------------------------------------------------------------
// Sample .NET 8 C# Service: Azure Blob Storage ERP WORM Integration
// Demonstrates invoice ingestion with VeriFactu metadata and Archive rehydration.
// NuGet packages required: Azure.Storage.Blobs, Azure.Identity
// ------------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Azure.Identity;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;

namespace Nubenetes.ErpStorage.Compliance
{
    public class InvoiceStorageService
    {
        private readonly BlobServiceClient _blobServiceClient;
        private readonly string _containerName;

        public InvoiceStorageService(string storageAccountName, string containerName = "facturas")
        {
            var uri = new Uri($"https://{storageAccountName}.blob.core.windows.net");
            // Zero-Trust: Uses Microsoft Entra ID Managed Identity / Developer Credentials
            _blobServiceClient = new BlobServiceClient(uri, new DefaultAzureCredential());
            _containerName = containerName;
        }

        /// <summary>
        /// Uploads an invoice PDF to the WORM container with compliance metadata and index tags.
        /// </summary>
        public async Task<string> UploadInvoiceAsync(
            Stream fileStream,
            string invoiceNumber,
            int fiscalYear,
            string customerTaxId,
            string chainedHash)
        {
            var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
            var blobPath = $"{fiscalYear}/{invoiceNumber}.pdf";
            var blobClient = containerClient.GetBlobClient(blobPath);

            var metadata = new Dictionary<string, string>
            {
                { "invoice_number", invoiceNumber },
                { "fiscal_year", fiscalYear.ToString() },
                { "customer_tax_id", customerTaxId },
                { "verifactu_hash", chainedHash },
                { "uploaded_utc", DateTime.UtcNow.ToString("O") },
                { "legal_framework", "CodigoDeComercioArt30_VeriFactu" }
            };

            var tags = new Dictionary<string, string>
            {
                { "InvoiceNumber", invoiceNumber.Replace("-", "_") },
                { "FiscalYear", fiscalYear.ToString() },
                { "CustomerTaxID", customerTaxId }
            };

            var options = new BlobUploadOptions
            {
                Metadata = metadata,
                Tags = tags
            };

            // In WORM containers, overwrites are prevented server-side
            await blobClient.UploadAsync(fileStream, options);
            return blobClient.Uri.ToString();
        }

        /// <summary>
        /// Requests background rehydration of an archived invoice (older than 3 years) for tax audits.
        /// </summary>
        public async Task RequestRehydrationAsync(string blobPath, bool highPriority = false)
        {
            var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
            var blobClient = containerClient.GetBlobClient(blobPath);

            var priority = highPriority ? RehydratePriority.High : RehydratePriority.Standard;
            await blobClient.SetAccessTierAsync(AccessTier.Cool, priority: priority);
        }
    }
}
