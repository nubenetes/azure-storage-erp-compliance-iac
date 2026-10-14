# Marco Legal y Cumplimiento Normativo: España y Unión Europea

---

### 🧭 Navegación de la Documentación
| 🏠 [Inicio / README](../README.md) | 🏛️ [Arquitectura](ARCHITECTURE.md) | ⚖️ **Marco Legal** | 💰 [Optimización de Costes](COST_OPTIMIZATION.md) | 🔒 [Guía WORM Lock](WORM_POLICY_LOCK_GUIDE.md) | 🖱️ [Manual Portal](AZURE_PORTAL_CLICKOPS_GUIDE.md) | 📊 [Auditoría & KQL](AUDITING_AND_MONITORING.md) | 🔌 [Integración ERP](ERP_INTEGRATION_AND_REHYDRATION.md) | 🚀 [Guía CI/CD](CICD_AUTOMATION_GUIDE.md) |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |

---

Este documento detalla los fundamentos jurídicos españoles y europeos que regulan la conservación de facturas electrónicas y pedidos comerciales, justificando las decisiones técnicas y de arquitectura implementadas en este repositorio.

---

## 📑 Tabla de Contenidos
1. [Matriz de Mapeo Normativo y Técnico](#1-matriz-de-mapeo-normativo-y-técnico)
2. [Análisis Detallado de la Legislación Aplicable](#2-análisis-detallado-de-la-legislación-aplicable)
   * 2.1. [Código de Comercio (Art. 30.1)](#21-código-de-comercio-art-301)
   * 2.2. [Ley 11/2021 de Prevención del Fraude Fiscal](#22-ley-112021-medidas-de-prevención-y-lucha-contra-el-fraude-fiscal)
   * 2.3. [Real Decreto 1007/2023 (Reglamento VeriFactu)](#23-real-decreto-10072023-reglamento-de-sistemas-informáticos-de-facturación---verifactu)
   * 2.4. [Residencia del Dato y RGPD en Spain Central](#24-residencia-del-dato-y-rgpd-spain-central)
3. [Certificaciones de Azure Spain Central](#3-certificaciones-de-azure-spain-central)
4. [Referencias Oficiales y Publicaciones en Boletines Oficiales](#4-referencias-oficiales-y-publicaciones-en-boletines-oficiales)
5. [Navegación entre Módulos de Documentación](#-navegación-entre-módulos)

---

## 1. Matriz de Mapeo Normativo y Técnico

| Normativa | Ámbito y Artículo | Requisito Legal | Implementación Técnica en Azure |
| :--- | :--- | :--- | :--- |
| **Código de Comercio** | Art. 30.1 | Conservación obligatoria de libros, correspondencia y justificantes comerciales durante **6 años** desde el último asiento. | Directiva de retención inmutable WORM fijada en **2.190 días** (6 años naturales). |
| **Ley General Tributaria (LGT)** | Ley 58/2003, Art. 66-70 | Plazo de prescripción tributaria general de **4 años** (IVA, Impuesto sobre Sociedades, IRPF). | Cubierto íntegramente por la directiva de 6 años; transición automática a nivel Frío (*Cold*) en el año 1 y Archivo (*Archive*) en el año 3. |
| **Ley General Tributaria (LGT)** | Ley 58/2003, Art. 66 bis | Derecho de la Agencia Tributaria (AEAT) a comprobar deducciones y bases imponibles negativas (BINs) durante **10 años**. | La directiva WORM puede ampliarse y los registros históricos pueden conservarse indefinidamente en nivel Archivo (~0,00099 €/GB/mes). |
| **Ley Antifraude** | Ley 11/2021, Art. 29.2.j | Los sistemas informáticos de facturación deben garantizar **integridad, conservación, accesibilidad, legibilidad, trazabilidad e inalterabilidad**. | El modo WORM de Azure Blob Storage imposibilita la modificación, sobrescritura o eliminación de facturas, incluso para administradores. |
| **Reglamento VeriFactu** | Real Decreto 1007/2023 | Facturación con registros encadenados (*hash* SHA-256), firma digital y custodia de registros de eventos sin posibilidad de alteración. | `allowProtectedAppendWrites = true` habilita la adición secuencial de bloques de eventos y hashes sin riesgo de sobrescritura de datos existentes. |
| **RGPD / LOPDGDD** | RGPD (UE) 2016/679 y LO 3/2018 | Soberanía de datos, protección de datos de carácter personal (NIF de autónomos, domicilios), medidas de seguridad técnicas y organizativas. | Región **Spain Central (Madrid)**: los datos permanecen bajo jurisdicción española/UE. Cifrado TLS 1.2+ en tránsito y AES-256 en reposo con Microsoft Entra ID RBAC. |
| **Esquema Nacional de Seguridad (ENS)** | RD 311/2022 | Marco de seguridad para el sector público y entidades que colaboren con las administraciones públicas (Categoría: **ALTO**). | Azure Spain Central cuenta con certificación oficial auditada del **ENS Nivel Alto**. |

---

## 2. Análisis Detallado de la Legislación Aplicable

### 2.1. Código de Comercio (Art. 30.1)
> *"Los empresarios conservarán los libros, correspondencia, documentación y justificantes concernientes a su negocio, debidamente ordenados, durante seis años, a partir del último asiento realizado en los libros, salvo lo que se establezca por disposiciones generales o especiales."*

* **Interpretación Jurídica**: Aunque el plazo de prescripción fiscal general de la Ley General Tributaria es de 4 años, el Código de Comercio impone un deber de custodia mercantil de 6 años. La destrucción o pérdida prematura de facturas antes de los 6 años acarrea sanciones, pérdida de valor probatorio en litigios mercantiles y responsabilidad personal de los administradores societarios.
* **Parámetro en IaC**: `retention_period_in_days = 2190` ($6 \times 365 = 2.190\text{ días}$).

---

### 2.2. Ley 11/2021 (Medidas de Prevención y Lucha contra el Fraude Fiscal)
La Ley 11/2021 introdujo en el artículo 29.2.j de la LGT la obligación de que los sistemas y programas informáticos o electrónicos que soporten los procesos contables, de facturación o de gestión de quienes desarrollen actividades económicas:
> *"Garantizarán la integridad, conservación, accesibilidad, legibilidad, trazabilidad e inalterabilidad de los registros, sin interpolaciones, omisiones o alteraciones de las que no quede la debida constancia en los sistemas mismos."*

* **Interpretación Jurídica**: Cualquier software contable o infraestructura de almacenamiento que permita borrar o modificar una factura sin dejar rastro inalterable se considera software de doble uso o sistema infractor, con multas de hasta 50.000 € por la mera tenencia del sistema no conforme.
* **Parámetro en IaC**: Azure Blob Storage en modo **WORM (*Write Once, Read Many*)** con **Bloqueo Definitivo de Directiva (*Policy Lock*)**. Los blobs almacenados en el contenedor quedan sellados criptográficamente; ningún usuario, script ni administrador puede borrar o sobreescribir facturas hasta cumplidos los 2.190 días.

---

### 2.3. Real Decreto 1007/2023 (Reglamento de Sistemas Informáticos de Facturación - VeriFactu)
El reglamento técnico establece los estándares para los registros de facturación:
1. **Inalterabilidad y Encadenamiento**: Cada registro de facturación emitido debe incorporar la huella digital (*hash* criptográfico) encadenada al registro inmediatamente anterior.
2. **Custodia de Registros de Eventos**: El sistema debe registrar cualquier incidencia, reinicio, anomalía o brecha de seguridad en un registro de auditoría protegido.
3. **Almacenamiento Seguro**: Si el ERP no remite inmediatamente las facturas a la sede electrónica de la AEAT (modalidad No-VeriFactu), debe mantener una copia inmutable, accesible y legible para inspección telemática inmediata.
* **Parámetro en IaC**: `allowProtectedAppendWrites = true`. Este parámetro autoriza al ERP a añadir secuencialmente nuevos bloques de registros de auditoría y hashes sin permitir en ningún momento modificar o eliminar los bloques consolidados previamente.

---

### 2.4. Residencia del Dato y RGPD (Spain Central)
El almacenamiento de facturas implica el tratamiento de datos personales de personas físicas (autónomos con NIF, administradores, empleados y clientes particulares con domicilios).

1. **Soberanía Territorial**: Desplegar en la región `spaincentral` (centros de datos en la Comunidad de Madrid) garantiza que los datos permanecen bajo jurisdicción española y comunitaria, eliminando riesgos y complejidades de transferencias internacionales de datos (Capítulo V del RGPD).
2. **Derecho de Supresión vs. Obligación Legal**: Conforme al artículo 17.3.b del RGPD, el derecho al olvido/supresión no aplica cuando el tratamiento es necesario para el cumplimiento de una obligación legal que requiera el tratamiento de datos impuesta por el Derecho de la Unión o de los Estados miembros (en este caso, Código de Comercio y LGT). El bloqueo WORM de 2.190 días está plenamente respaldado frente a peticiones indebidas de borrado.
3. **Seguridad y Cifrado**:
   * En tránsito: Imposición obligatoria de TLS 1.2 o superior (`min_tls_version = "TLS1_2"`).
   * En reposo: Cifrado transparente con clave AES-256 gestionada por la plataforma (*Storage Service Encryption*).

---

## 3. Certificaciones de Azure Spain Central

Microsoft Azure opera sus centros de datos de la región Spain Central bajo los siguientes esquemas de cumplimiento validados por auditores independientes:
* **ENS (Esquema Nacional de Seguridad) - Categoría ALTO**: Certificado oficial emitido por BSI / CCN-CERT.
* **ISO/IEC 27001, 27017, 27018, 27701**: Seguridad de la información, seguridad en la nube y privacidad de datos personales.
* **SOC 1, SOC 2, SOC 3**: Informes de controles en organizaciones de servicios para auditorías financieras y operativas.

---

## 4. Referencias Oficiales y Publicaciones en Boletines Oficiales

1. **Código de Comercio de España**: [Real Decreto de 22 de agosto de 1885 (BOE-A-1885-6627)](https://www.boe.es/buscar/act.php?id=BOE-A-1885-6627#a30).
2. **Ley 58/2003, General Tributaria (LGT)**: [Texto consolidado (BOE-A-2003-23186)](https://www.boe.es/buscar/act.php?id=BOE-A-2003-23186).
3. **Ley 11/2021 de Medidas contra el Fraude Fiscal**: [Publicación oficial (BOE-A-2021-11473)](https://www.boe.es/buscar/act.php?id=BOE-A-2021-11473).
4. **Real Decreto 1007/2023 (Reglamento VeriFactu)**: [Requisitos de sistemas de facturación (BOE-A-2023-24840)](https://www.boe.es/buscar/act.php?id=BOE-A-2023-24840).
5. **Agencia Estatal de Administración Tributaria (AEAT)**: [Guía técnica y normativa de Sistemas de Facturación](https://sede.agenciatributaria.gob.es/Sede/procedimientoini/GZ28.shtml).
6. **Reglamento General de Protección de Datos (RGPD)**: [Reglamento (UE) 2016/679 del Parlamento Europeo y del Consejo](https://eur-lex.europa.eu/legal-content/ES/TXT/?uri=CELEX%3A32016R0679).
7. **CCN-CERT / Esquema Nacional de Seguridad**: [Portal del Esquema Nacional de Seguridad (RD 311/2022)](https://www.ccn-cert.cni.es/ens.html).
8. **Microsoft Learn - Almacenamiento Inmutable WORM**: [Documentación oficial de Azure Blob Storage Immutable](https://learn.microsoft.com/azure/storage/blobs/immutable-storage-overview).
9. **Microsoft Learn - Niveles de Acceso y Precios**: [Azure Blob Storage Tiers and Lifecycle Management](https://learn.microsoft.com/azure/storage/blobs/access-tiers-overview).

---

## 🧭 Navegación entre Módulos

* ⬅️ **Anterior**: [Referencia de Arquitectura Técnica](ARCHITECTURE.md)
* 🏠 **Inicio**: [README Principal](../README.md)
* ➡️ **Siguiente**: [Análisis Financiero y Optimización de Costes (TCO)](COST_OPTIMIZATION.md)
* 📑 **Índice Completo de Documentación**:
  1. 🏛️ [Arquitectura Técnica](ARCHITECTURE.md)
  2. ⚖️ **Marco Legal y Cumplimiento Normativo (España y UE)** (Documento actual)
  3. 💰 [Análisis Financiero y Optimización de Costes (TCO)](COST_OPTIMIZATION.md)
  4. 🔒 [Guía Operativa del Bloqueo WORM (Policy Lock)](WORM_POLICY_LOCK_GUIDE.md)
  5. 🖱️ [Manual Paso a Paso en Azure Portal (ClickOps)](AZURE_PORTAL_CLICKOPS_GUIDE.md)
  6. 📊 [Auditoría, Monitorización y Consultas KQL](AUDITING_AND_MONITORING.md)
  7. 🔌 [Guía de Integración ERP y Rehidratación](ERP_INTEGRATION_AND_REHYDRATION.md)
  8. 🚀 [Automatización CI/CD Multiplataforma](CICD_AUTOMATION_GUIDE.md)

