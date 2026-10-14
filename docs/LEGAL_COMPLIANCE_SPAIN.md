# Legal & Regulatory Compliance Framework: Spain & European Union

This document details the Spanish and European legal foundations governing digital invoice and commercial order retention, justifying the technical choices implemented in this repository.

---

## 1. Regulatory Mapping Matrix

| Regulation | Scope & Article | Legal Requirement | Technical Implementation in Azure |
| :--- | :--- | :--- | :--- |
| **Código de Comercio** | Art. 30.1 | Mandatory retention of commercial documents, books, and invoices for **6 years** from last entry. | Immutable WORM retention policy set to **2,190 days** (6 calendar years). |
| **Ley General Tributaria (LGT)** | Ley 58/2003, Art. 66-70 | General tax prescription period of **4 years** for VAT, Corporate Tax, and Personal Income Tax. | Covered within the 6-year WORM policy; Tiering to Cold tier at Year 1 and Archive tier at Year 3. |
| **Ley General Tributaria (LGT)** | Ley 58/2003, Art. 66 bis | Right of the tax administration (AEAT) to audit deductions and negative tax bases (BINs) for **10 years**. | WORM policy can be extended or historical records kept in Archive tier (~0.00099 €/GB/mo) indefinitely. |
| **Ley Antifraude** | Ley 11/2021, Art. 29.2.j | Billing systems must guarantee **integrity, conservation, accessibility, legibility, traceability, and inalterability**. | Azure Blob Storage WORM policy prevents modification, deletion, or truncation even by Admins. |
| **Reglamento VeriFactu** | Real Decreto 1007/2023 | Certified billing software must provide chained records (hashes), digital signing, and tamper-proof log custody. | `allowProtectedAppendWrites = true` enables appending event logs and invoice hash chains without overwrite risk. |
| **RGPD / LOPDGDD** | RGPD (UE) 2016/679 & LO 3/2018 | Data sovereignty, protection of personal data (CIF/NIF, fiscal addresses), security measures. | Region **Spain Central (Madrid)** ensures data never leaves Spain. TLS 1.2+ and Microsoft Entra ID RBAC. |
| **Esquema Nacional de Seguridad (ENS)** | RD 311/2022 | Security framework for public sector and entities collaborating with administration (Level: **ALTO**). | Azure Spain Central holds official **ENS Nivel Alto** certification. |

---

## 2. Deep Dive into Applicable Laws

### 2.1. Código de Comercio (Art. 30.1)
> *"Los empresarios conservarán los libros, correspondencia, documentación y justificantes concernientes a su negocio, debidamente ordenados, durante seis años, a partir del último asiento realizado en los libros, salvo lo que se establezca por disposiciones generales o especiales."*

* **Interpretation**: While tax law prescribes after 4 years, commercial law mandates 6 years. If a company disposes of invoices before 6 years, it faces severe penalties, liability in commercial lawsuits, and loss of evidentiary presumption.
* **IaC Setting**: `retention_period_in_days = 2190` ($6 \times 365 = 2,190\text{ days}$).

---

### 2.2. Ley 11/2021 (Medidas de Prevención y Lucha contra el Fraude Fiscal)
La Ley 11/2021 introdujo en el artículo 29.2.j de la LGT la obligación de que los sistemas y programas informáticos o electrónicos que soporten los procesos contables, de facturación o de gestión de quienes desarrollen actividades económicas:
> *"Garantizarán la integridad, conservación, accesibilidad, legibilidad, trazabilidad e inalterabilidad de los registros, sin interpolaciones, omisiones o alteraciones de las que no quede la debida constancia en los sistemas mismos."*

* **Interpretation**: Software or storage systems that allow deleting or altering an invoice without leaving an unalterable audit trace are illegal and subject to severe fines (up to 50,000 € for possession of non-compliant systems).
* **IaC Setting**: Azure Blob Storage **WORM (Write Once, Read Many)** with **Policy Lock**. Blobs uploaded to the container are cryptographically secured; no user, API call, or administrator role can overwrite or delete existing records until the retention timer has elapsed.

---

### 2.3. Real Decreto 1007/2023 (Reglamento de Sistemas Informáticos de Facturación - VeriFactu)
El reglamento técnico establece los estándares para los registros de facturación:
1. **Inalterabilidad**: Cada registro de facturación emitido debe incorporar un hash criptográfico encadenado al registro inmediatamente anterior.
2. **Custodia de Registros de Eventos**: El sistema debe registrar cualquier incidencia, reinicio o anomalía.
3. **Almacenamiento seguro**: Si el ERP no remite inmediatamente las facturas a la sede electrónica de la AEAT (modalidad No-VeriFactu), debe mantener una copia inmutable y accesible para inspección telemática.
* **IaC Setting**: `allowProtectedAppendWrites = true`. This parameter permits the ERP to append new billing log blocks and invoice hashes sequentially while strictly prohibiting the alteration or deletion of past committed blocks.

---

### 2.4. Residencia del Dato y RGPD (Spain Central)
El almacenamiento de facturas implica el tratamiento de datos personales de personas físicas (autónomos con NIF, administradores, destinatarios de facturas con domicilios particulares).

1. **Soberanía Territorial**: Desplegar en `spaincentral` (centros de datos en la Comunidad de Madrid) garantiza que los datos permanecen bajo jurisdicción española y europea, eliminando cualquier debate sobre transferencias internacionales de datos (Capítulo V del RGPD).
2. **Derecho de Supresión vs. Obligación Legal**: Conforme al artículo 17.3.b del RGPD, el derecho al olvido/supresión no aplica cuando el tratamiento es necesario para el cumplimiento de una obligación legal que requiera el tratamiento de datos impuesta por el Derecho de la Unión o de los Estados miembros (en este caso, Código de Comercio y LGT). El bloqueo WORM de 2.190 días está plenamente justificado frente a peticiones indebidas de borrado.
3. **Cifrado**:
   * En tránsito: Enforced TLS 1.2+ (`min_tls_version = "TLS1_2"`).
   * En reposo: Cifrado transparente con AES-256 (Azure Storage Service Encryption).

---

## 3. Certificaciones de Azure Spain Central

Microsoft Azure opera sus centros de datos de la región Spain Central bajo los siguientes esquemas de cumplimiento validados por auditores independientes:
* **ENS (Esquema Nacional de Seguridad) - Categoría ALTO**: Certificado oficial emitido por BSI / CCN-CERT.
* **ISO/IEC 27001, 27017, 27018, 27701**: Seguridad de la información y privacidad en la nube.
* **SOC 1, SOC 2, SOC 3**: Informes de controles en organizaciones de servicios para auditorías financieras.
