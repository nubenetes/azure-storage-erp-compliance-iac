# Financial Analysis & Cost Optimization: Azure Blob Storage ERP (1 TB)

This document provides the financial and mathematical justification for the access tiering architecture in **Spain Central (Madrid)** compared to standard storage patterns.

---

## 1. Regional Pricing Benchmark (Spain Central vs. West Europe vs. North Europe)

Prices are benchmarked in Euros (€) for Standard General Purpose v2 accounts:

| Access Tier | Spain Central (`spaincentral`) | West Europe (`westeurope`) | North Europe (`northeurope`) | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Hot (LRS)** | ~0.0184 € / GB / mo | ~0.0184 € / GB / mo | ~0.0184 € / GB / mo | Same list price |
| **Hot (ZRS)** | ~0.0230 € / GB / mo | ~0.0230 € / GB / mo | ~0.0230 € / GB / mo | Zone redundancy (3 AZs) |
| **Cool (LRS)** | ~0.0100 € / GB / mo | ~0.0100 € / GB / mo | ~0.0100 € / GB / mo | **~46% savings** |
| **Cold (LRS)** | ~0.0045 € / GB / mo | ~0.0045 € / GB / mo | ~0.0045 € / GB / mo | **~76% savings** |
| **Archive (LRS)**| ~0.00099 € / GB / mo| ~0.00099 € / GB / mo| ~0.00099 € / GB / mo| **~95% savings** |
| **Network Egress (Spain)** | **< 10 ms (intra-country)** | 30-45 ms (cross-border) | 35-50 ms (cross-border) | Zero latency tax, local routing |

> [!NOTE]
> Azure charges the exact same storage base price in **Spain Central (Madrid)** as in Amsterdam and Dublin. Choosing Spain Central brings direct latency gains, legal data sovereignty, and zero price penalty.

---

## 2. Mathematical TCO Model for 1 TB ERP Invoices & Orders

### Assumptions
* **Cumulative Volume**: 1,000 GB (1 TB) accumulated over 6 years of business operations.
* **Monthly Ingestion**: ~13.88 GB of new invoices and orders generated per month (~166.6 GB/year).
* **Document Retention**: 6 years (2,190 days) pursuant to Article 30 of the Spanish Commercial Code.
* **Redundancy Model**: Calculations below are presented for both LRS and ZRS.

### Data Distribution in Steady State (Year 6)

```text
Total Pool = 1,000 GB
├── Hot Tier (Days 0 - 90, 3 months):      41.67 GB  (4.17%)
├── Cool Tier (Days 91 - 365, 9 months):   125.00 GB (12.50%)
├── Cold Tier (Years 1 - 3, 24 months):    333.33 GB (33.33%)
└── Archive Tier (Years 3 - 6, 36 months): 500.00 GB (50.00%)
```

---

## 3. Cost Comparison: Traditional All-Hot vs. Automated Tiering

### Scenario A: Traditional Approach (100% Hot Tier)
All 1 TB remains in the Hot tier indefinitely.

| Component | LRS Monthly | ZRS Monthly | Annual Cost (LRS) | Annual Cost (ZRS) |
| :--- | :--- | :--- | :--- | :--- |
| 1,000 GB in Hot Tier | 18.40 € | 23.00 € | 220.80 € | 276.00 € |
| Operations (Read/Write) | ~0.40 € | ~0.40 € | 4.80 € | 4.80 € |
| **Total Monthly Cost** | **~18.80 €** | **~23.40 €** | **~225.60 €** | **~280.80 €** |

---

### Scenario B: Automated Lifecycle Tiering (This Architecture)
Data automatically transitions through Hot $\rightarrow$ Cool $\rightarrow$ Cold $\rightarrow$ Archive.

| Tier / Component | Data Volume | LRS Rate (€/GB/mo) | ZRS Rate (€/GB/mo) | Monthly Cost (LRS) | Monthly Cost (ZRS) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Hot** (Recent invoices, 0-90d) | 41.67 GB | 0.0184 € | 0.0230 € | 0.77 € | 0.96 € |
| **Cool** (Fiscal year, 91-365d) | 125.00 GB | 0.0100 € | 0.0125 € | 1.25 € | 1.56 € |
| **Cold** (Audits, 1-3y) | 333.33 GB | 0.0045 € | 0.0058 € | 1.50 € | 1.93 € |
| **Archive** (Statutory custody, 3-6y) | 500.00 GB | 0.00099 € | 0.00125 € | 0.50 € | 0.63 € |
| Operations & Lifecycle transitions | ~13.88 GB/mo | - | - | ~0.35 € | ~0.35 € |
| **Total Monthly Cost** | **1,000 GB** | - | - | **~4.37 € / mo** | **~5.43 € / mo** |

---

## 4. Financial Savings Summary

| Metric | All-Hot Architecture | Automated Tiering (LRS) | Automated Tiering (ZRS) |
| :--- | :--- | :--- | :--- |
| **Monthly Bill** | 18.80 € | **4.37 €** | **5.43 €** |
| **Annual Bill** | 225.60 € | **52.44 €** | **65.16 €** |
| **6-Year TCO** | 1,353.60 € | **314.64 €** | **390.96 €** |
| **Absolute Savings (6 years)**| Baseline | **1,038.96 € saved** | **962.64 € saved** |
| **Relative Savings (%)** | Baseline | **76.8% Reduction** | **71.1% Reduction (with 3-zone HA)** |

> [!TIP]
> Notice that **Automated Tiering with ZRS** (3 availability zones in Madrid) costs **only ~5.43 €/month**, which is **~71% cheaper** than keeping data in a single data center (LRS) on Hot tier!

---

## 5. Operations, Retrieval & Rehydration Considerations

When designing tiering for ERP documents, operational costs must be accounted for:

1. **Read Operations**:
   * **Hot**: Zero retrieval fee. Best for active customer portal access.
   * **Cool**: Small read fee (~0.01 € per GB retrieved). Negligible for quarterly/annual queries.
   * **Cold**: Retrieval fee (~0.03 € per GB). Still very economical for tax audits occurring once every few years.
   * **Archive**: Rehydration fee (~0.022 € per GB) + time delay (Standard: 3-15 hours; High Priority: < 1 hour). Since documents 3+ years old are rarely accessed except under formal administrative requirements, keeping 500 GB in Archive saves ~8.70 €/month, while rehydrating 10 GB for an audit costs under 0.25 €.
2. **Lifecycle Transition Operations**:
   * Moving blobs between tiers incurs a write operation fee per 10,000 blobs (~0.05 € - 0.10 €). For ~10,000 invoices per month, transition transactions amount to less than 0.10 €/month.
3. **Minimum Retention Periods**:
   * Cool: 30 days minimum retention.
   * Cold: 90 days minimum retention.
   * Archive: 180 days minimum retention.
   * *Our lifecycle rules transition data at 90 days, 365 days, and 1,095 days, thereby perfectly exceeding all minimum retention thresholds without early deletion penalties.*
