# Step-by-Step Azure Portal Guide (Manual / ClickOps)

This guide provides exhaustive, click-by-click instructions to provision and configure the complete ERP WORM compliance and cost-optimized tiering architecture using the **Azure Portal** ([portal.azure.com](https://portal.azure.com)).

---

## Prerequisites
* An active **Microsoft Azure Subscription** with `Contributor` or `Owner` permissions.
* Access to the **Spain Central (Madrid)** region.

---

## Table of Contents
1. [Step 1: Create the Resource Group](#step-1-create-the-resource-group)
2. [Step 2: Create the Storage Account (ZRS & Security Hardening)](#step-2-create-the-storage-account-zrs--security-hardening)
3. [Step 3: Enable Advanced Data Protection (Soft Delete & Versioning)](#step-3-enable-advanced-data-protection-soft-delete--versioning)
4. [Step 4: Create ERP Containers (`facturas` & `pedidos`)](#step-4-create-erp-containers-facturas--pedidos)
5. [Step 5: Configure WORM Immutability Policy (2,190 Days / 6 Years)](#step-5-configure-worm-immutability-policy-2190-days--6-years)
6. [Step 6: Configure Automated Lifecycle Management (Tiering Rules)](#step-6-configure-automated-lifecycle-management-tiering-rules)
7. [Step 7: Apply the `CanNotDelete` Azure Resource Lock](#step-7-apply-the-cannotdelete-azure-resource-lock)
8. [Step 8: Verification, Test Ingestion & Permanent Policy Lock](#step-8-verification-test-ingestion--permanent-policy-lock)

---

## Step 1: Create the Resource Group

1. Log in to [portal.azure.com](https://portal.azure.com).
2. In the top search bar, type **Resource groups** and select it from the results.
3. Click **+ Create** (top left).
4. Configure the **Basics** tab:
   * **Subscription**: Select your target Azure subscription.
   * **Resource group**: Enter `rg-erp-storage-prod-spaincentral`.
   * **Region**: Select **(Europe) Spain Central**.
5. Switch to the **Tags** tab and add:
   * `Workload`: `ERP-Document-Archive`
   * `LegalCompliance`: `Codigo-de-Comercio-Art30-VeriFactu`
   * `Country`: `Spain`
6. Click **Review + create**, then click **Create**.

---

## Step 2: Create the Storage Account (ZRS & Security Hardening)

1. Navigate to your newly created resource group `rg-erp-storage-prod-spaincentral`.
2. Click **+ Create** or **+ Add resource**, search for **Storage account**, and select **Create**.
3. **Basics Tab**:
   * **Subscription**: Your subscription.
   * **Resource group**: `rg-erp-storage-prod-spaincentral`.
   * **Storage account name**: Enter a unique name, e.g., `sterpspainprod01` (3–24 lowercase alphanumerics).
   * **Region**: **(Europe) Spain Central**.
   * **Primary service**: **Azure Blob Storage or Azure Data Lake Storage Gen 2**.
   * **Performance**: **Standard** (general-purpose v2).
   * **Redundancy**: Select **Zone-redundant storage (ZRS)**.
     *(ZRS replicates your data synchronously across three Azure availability zones in Madrid. You can choose LRS for non-production environments to lower cost).*

4. **Advanced Tab**:
   * **Require secure transfer for REST API operations**: Checked (Enabled).
   * **Enable infrastructure encryption**: Optional (select if double encryption is required).
   * **Allow enabling public access on individual containers**: **Unchecked (Disabled)** *(Critical for Zero Trust)*.
   * **Enable storage account key access**: Checked (or uncheck if strictly using Entra ID RBAC).
   * **Default to Microsoft Entra authorization in the Azure portal**: Checked.
   * **Minimum TLS version**: **Version 1.2**.
   * **Permitted scope for copy operations**: Any storage account or within the same tenant.
   * **Hierarchical namespace**: Disabled (standard flat blob namespace).
   * **Access tier**: **Hot** *(default for active ingestion)*.

5. **Networking Tab**:
   * **Network access**:
     * For initial setup: Select **Enable public access from all networks**.
     * For production firewall: Select **Enable public access from selected virtual networks and IP addresses**, then add your corporate ERP server outbound public IPs.
   * **Network routing**: **Microsoft network routing** (lowest latency within Spain).

6. **Data protection Tab**:
   * *Recovery*:
     * **Enable soft delete for blobs**: **Checked**, set to **30 days**.
     * **Enable soft delete for containers**: **Checked**, set to **30 days**.
     * **Enable soft delete for shares**: Optional (not used for blob).
   * *Tracking*:
     * **Enable versioning for blobs**: **Checked**.
     * **Enable blob change feed**: **Checked**.

7. **Review + create Tab**:
   * Verify all configurations and click **Create**. Wait 1–2 minutes for deployment to finish.

---

## Step 3: Enable Advanced Data Protection (Soft Delete & Versioning)

*(If you skipped configuring Data Protection during account creation)*:

1. Open your Storage Account `sterpspainprod01`.
2. In the left navigation menu under **Data management**, select **Data protection**.
3. Check:
   * **Enable soft delete for blobs** $\rightarrow$ `30` days.
   * **Enable soft delete for containers** $\rightarrow$ `30` days.
   * **Turn on versioning for blobs** $\rightarrow$ Checked.
   * **Turn on blob change feed** $\rightarrow$ Checked.
4. Click **Save** at the top.

---

## Step 4: Create ERP Containers (`facturas` & `pedidos`)

1. Inside your Storage Account, go to the left menu under **Data storage** and click **Containers**.
2. Click **+ Container**:
   * **Name**: `facturas`
   * **Public access level**: **Private (no anonymous access)**
   * Click **Create**.
3. Click **+ Container** again:
   * **Name**: `pedidos`
   * **Public access level**: **Private (no anonymous access)**
   * Click **Create**.

---

## Step 5: Configure WORM Immutability Policy (2,190 Days / 6 Years)

Repeat these steps for both `facturas` and `pedidos`:

1. In the **Containers** list, click on the container name (e.g., `facturas`).
2. In the left sub-menu under **Settings**, select **Access policy**.
3. Under the **Immutable blob storage** section, click **+ Add policy**.
4. Configure the policy dialog:
   * **Policy type**: Select **Time-based retention**.
   * **Retention period**: Enter **`2190`** (days).
   * **Allow additional append writes**: **Checked** *(Enables `allowProtectedAppendWrites = true` for VeriFactu append logs and invoice hash audit trails)*.
5. Click **Save**.
6. The policy is now active in **Unlocked** state.

> [!NOTE]
> In **Unlocked** state, blobs are already protected against modification and deletion. You can run integration tests safely. Do NOT click "Lock policy" until you have validated your ERP uploads.

---

## Step 6: Configure Automated Lifecycle Management (Tiering Rules)

1. Return to the Storage Account overview and scroll down the left menu to **Data management** $\rightarrow$ **Lifecycle management**.
2. Click **+ Add a rule**.
3. **Details Tab**:
   * **Rule name**: `tier-erp-invoices-and-orders`
   * **Rule scope**: Select **Limit blobs with filters**.
   * **Blob type**: Check **Block blobs**.
   * **Blob subtype**: Check **Base blobs**, **Snapshots**, and **Versions**.
   * Click **Next**.

4. **Base blobs Tab**:
   * Check **Move to cool storage** $\rightarrow$ Enter **`90`** days after last modified.
   * Check **Move to cold storage** $\rightarrow$ Enter **`365`** days after last modified.
   * Check **Move to archive storage** $\rightarrow$ Enter **`1095`** days after last modified.
   * Click **Next**.

5. **Snapshots Tab**:
   * Check **Move to cool storage** $\rightarrow$ Enter **`90`** days after creation.
   * Check **Move to cold storage** $\rightarrow$ Enter **`365`** days after creation.
   * Check **Move to archive storage** $\rightarrow$ Enter **`1095`** days after creation.
   * Click **Next**.

6. **Versions Tab**:
   * Check **Move to cool storage** $\rightarrow$ Enter **`90`** days after creation.
   * Check **Move to cold storage** $\rightarrow$ Enter **`365`** days after creation.
   * Check **Move to archive storage** $\rightarrow$ Enter **`1095`** days after creation.
   * Click **Next**.

7. **Filter set Tab**:
   * In **Blob prefix**, enter:
     * `facturas/`
     * `pedidos/`
8. Click **Add**.

---

## Step 7: Apply the `CanNotDelete` Azure Resource Lock

1. In the left menu of the Storage Account, locate the **Settings** section and click **Locks**.
2. Click **+ Add**:
   * **Lock name**: `lock-erp-storage-prevent-deletion`
   * **Lock type**: Select **Delete** *(which corresponds to `CanNotDelete`)*.
   * **Notes**: `Protects ERP compliance storage account against accidental or malicious deletion.`
3. Click **OK**.

---

## Step 8: Verification, Test Ingestion & Permanent Policy Lock

### 1. Test Ingestion and Deletion Block
1. Navigate to **Containers** $\rightarrow$ `facturas`.
2. Click **Upload** and upload a test file (e.g., `test_invoice_001.pdf`).
3. Select the uploaded blob and click **Delete**.
4. Observe the deletion failure message:
   ```text
   Failed to delete 1 out of 1 blob(s):
   The operation is not permitted due to a Time-Based Retention Policy. (Code: BlobImmutableDueToPolicy)
   ```

### 2. Permanently Lock the WORM Policy (Production Only)

> [!CAUTION]
> Once locked, **NO ONE** (including Azure Global Administrators or Microsoft Support) can delete the policy or the blobs for 2,190 days.

1. Go to **Containers** $\rightarrow$ `facturas` $\rightarrow$ **Access policy**.
2. Locate the Time-based retention policy.
3. Click the context menu **`...`** (three dots) on the right side of the policy.
4. Select **Lock policy**.
5. Read the confirmation dialog, type the required confirmation value or check the box, and click **Lock policy**.
6. The state will switch from **Unlocked** to **Locked**.
