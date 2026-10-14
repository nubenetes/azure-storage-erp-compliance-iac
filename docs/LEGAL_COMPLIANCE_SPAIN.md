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
3. [Régimen Sancionador: Costes y Penalizaciones Económicas por Incumplimiento WORM](#3-régimen-sancionador-costes-y-penalizaciones-económicas-por-incumplimiento-worm)
   * 3.1. [Sanción Fija de 50.000 € por Ejercicio (Art. 201 bis LGT)](#31-sanción-fija-de-50000--por-ejercicio-por-software-no-conforme-art-201-bis-lgt)
   * 3.2. [Sanción Proporcional del 2% al 5% por Falta de Conservación (Art. 201 LGT)](#32-sanción-proporcional-del-2-al-5-por-falta-de-conservación-o-facturas-ilegibles-art-201-lgt)
   * 3.3. [Pérdida de Deducibilidad del IVA y del Impuesto sobre Sociedades](#33-pérdida-de-deducibilidad-del-iva-soportado-y-del-gasto-en-impuesto-sobre-sociedades)
   * 3.4. [Impacto en Auditoría de Cuentas (LAC) y Bloqueo Societario](#34-impacto-en-la-auditoría-de-cuentas-anuales-ley-222015-lac-y-bloqueo-societario)
   * 3.5. [Calificación de Concurso Culpable y Responsabilidad de Administradores](#35-calificación-de-concurso-culpable-y-responsabilidad-patrimonial-de-los-administradores)
   * 3.6. [Infracciones de Protección de Datos (RGPD / AEPD)](#36-infracciones-de-protección-de-datos-rgpd--aepd)
   * 3.7. [Matriz Resumen: Protección WORM vs. Riesgo de Sanción](#37-matriz-resumen-coste-de-protección-worm-vs-riesgo-de-sanción)
4. [Certificaciones de Azure Spain Central](#4-certificaciones-de-azure-spain-central)
5. [Referencias Oficiales y Publicaciones en Boletines Oficiales](#5-referencias-oficiales-y-publicaciones-en-boletines-oficiales)
6. [Navegación entre Módulos de Documentación](#-navegación-entre-módulos)

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

## 3. Régimen Sancionador: Costes y Penalizaciones Económicas por Incumplimiento WORM

Cuando una empresa es objeto de una inspección tributaria de la **Agencia Estatal de Administración Tributaria (AEAT)**, una auditoría financiera externa regulada por la **Ley de Auditoría de Cuentas (LAC)** o un procedimiento judicial mercantil, la ausencia de un mecanismo técnico de inmutabilidad como **WORM (*Write Once, Read Many*) con bloqueo irreversible** acarrea graves consecuencias pecuniarias, operativas y patrimoniales.

A continuación se desglosan las sanciones económicas tipificadas en el marco jurídico español vigente:

### 3.1. Sanción Fija de 50.000 € por Ejercicio por Software No Conforme (Art. 201 bis LGT)
La **Ley 11/2021 de Medidas contra el Fraude Fiscal** tipificó en el artículo 201 bis de la Ley General Tributaria como **infracción tributaria grave**:
> *«Constituye infracción tributaria la tenencia de sistemas o programas informáticos o electrónicos que no se ajusten a lo establecido en el artículo 29.2.j) de esta Ley, cuando los mismos no estén debidamente certificados teniendo que estarlo por disposición reglamentaria, o cuando se hayan alterado o modificado los dispositivos certificados.»*

* **Cuantía de la Multa**: **50.000 € fijos por cada ejercicio económico** en el que se haya utilizado el sistema de facturación o almacenamiento no conforme para el usuario o empresa titular.
* **Efecto Acumulativo en Inspección**: Dado que la AEAT inspecciona con carácter habitual los **4 ejercicios fiscales no prescritos** (por ejemplo, 2023, 2024, 2025 y 2026), la sanción directa asciende a:
  $$\text{Sanción Art. 201 bis LGT} = 50.000\text{ €} \times 4\text{ ejercicios} = \mathbf{200.000\text{ €}}$$
* **Responsabilidad del Fabricante / Proveedor de Software**: La comercialización o distribución de software o sistemas de facturación que permitan alterar, interpolar o eliminar facturas sin bloqueo inmutable conlleva una sanción de **150.000 € por cada ejercicio de venta** o el 20% del volumen de negocio.

---

### 3.2. Sanción Proporcional del 2% al 5% por Falta de Conservación o Facturas Ilegibles (Art. 201 LGT)
El artículo 201 de la LGT sanciona el incumplimiento de las obligaciones de facturación y conservación documental:
* **Falta de conservación de facturas o justificantes**: Sanción pecuniaria proporcional del **2% al 5% del importe total de las operaciones** respecto de las cuales se haya producido el incumplimiento.
* **Cuantía no determinada**: Si no resulta posible determinar el importe exacto de las facturas alteradas o destruidas por carecer de inmutabilidad WORM, la sanción es de **300 € por cada factura o documento afectado**.
* **Ejemplo Práctico**: Para una empresa con una facturación media de 10.000.000 € anuales, si tras un borrado o alteración en una cuenta de almacenamiento estándar mutable no puede acreditar la custodia íntegra de un ejercicio, la sanción del 2% al 5% oscila entre **200.000 € y 500.000 €**.

---

### 3.3. Pérdida de Deducibilidad del IVA Soportado y del Gasto en Impuesto sobre Sociedades
Conforme al artículo 97 de la Ley 37/1992 del IVA y el artículo 106 de la LGT, la deducción del IVA soportado y la justificación de gastos deducibles en el Impuesto sobre Sociedades (IS) exige **la posesión del documento original justificativo completo, auténtico e inalterado**.

Si el auditor o inspector de la AEAT detecta que los registros y ficheros PDF/XML carecen de garantía técnica de inmutabilidad (o se constata que pudieron ser sobrescritos por usuarios con privilegios en el ERP o en Azure):
1. **Expulsión de Deducciones (Liquidación de Cuota)**: Se desestiman todas las cuotas soportadas de IVA y las partidas de gasto asociadas a los justificantes no fehacientes.
2. **Intereses de Demora Tributarios**: Exigencia del interés legal de demora (~4,06% anual) acumulado durante los años de inspección.
3. **Sanción Tributaria por Dejar de Ingresar Cuota (Art. 191 LGT)**:
   * Sanción tipificada como **grave o muy grave** por empleo de anomalías sustanciales en contabilidad o facturación.
   * Multa pecuniaria proporcional de entre el **50% y el 150% de la cuota no ingresada**.
* **Impacto Económico**: Para 100.000 € de IVA o gasto rechazado, la cuota devuelta más la sanción del 100% y los intereses sitúa el coste económico en más de **220.000 €**.

---

### 3.4. Impacto en la Auditoría de Cuentas Anuales (Ley 22/2015, LAC) y Bloqueo Societario
Cuando los auditores de cuentas independientes (inscritos en el ROAC) auditan las cuentas anuales de la sociedad, evalúan el Control Interno de los Sistemas de Información (ITGC - *Information Technology General Controls*). Si el almacenamiento de facturas permite la eliminación o alteración física de ficheros:
1. **Opinión con Salvedades o Denegación de Opinión por Limitación al Alcance**: El auditor certifica la imposibilidad de obtener evidencia de auditoría suficiente y adecuada respecto a la integridad del corte de ventas y compras (*Cut-Off*).
2. **Rechazo del Depósito de Cuentas en el Registro Mercantil**: El Registrador Mercantil no admite el depósito de cuentas anuales con informe denegatorio o con salvedades sustanciales.
3. **Cierre de la Hoja Registral Mercantil (Art. 378 RRM)**: Pasado un año desde el cierre del ejercicio sin cuentas depositadas, se decreta el cierre registral. La sociedad queda imposibilitada para inscribir nombramientos de administradores, otorgamiento de poderes notariales o modificaciones estatutarias.
4. **Vencimiento Anticipado de Créditos Bancarios (*Covenants*)**: Las entidades financieras exigen estados financieros auditados limpios. La opinión modificada activa cláusulas de resolución inmediata de líneas de crédito y pólizas de circulante.
5. **Prohibición de Contratar con el Sector Público (Art. 71 LCSP)**: Exclusión automática en concursos y licitaciones públicas de la Administración por infracción tributaria firme o falta de solvencia acreditada.

---

### 3.5. Calificación de Concurso Culpable y Responsabilidad Patrimonial de los Administradores
En caso de que la mercantil atraviese dificultades de liquidez y entre en procedimiento concursal (Ley Concursal, Real Decreto Legislativo 1/2020):
* **Artículos 443 y 444 TRLC**: El concurso se califica forzosamente como **CULPABLE** cuando el deudor:
  - Hubiera cometido irregularidad relevante para la comprensión de su situación patrimonial o financiera en la llevanza de la contabilidad.
  - Hubiera destruido o alterado libros, justificantes o documentación contable antes del vencimiento del plazo legal de 6 años (Art. 30 Código de Comercio).
* **Derivación de Responsabilidad Personal (Déficit Concursal)**: El juez del concurso condena a los administradores societarios a **cubrir el déficit patrimonial de la sociedad con sus propios bienes y patrimonio personal**, de manera ilimitada y solidaria, junto con la inhabilitación mercantil de 2 a 15 años.

---

### 3.6. Infracciones de Protección de Datos (RGPD / AEPD)
Las facturas de autónomos, clientes particulares y profesionales contienen datos de carácter personal (NIF, nombre, domicilio fiscal, compras realizadas, cuentas IBAN).
* La alteración o pérdida de integridad documental vulnera el principio de **integridad y confidencialidad** (Art. 5.1.f RGPD) y el deber de implantar medidas técnicas de seguridad adecuadas (Art. 32 RGPD).
* **Sanciones de la AEPD**: Multas de hasta **20.000.000 € o el 4% del volumen de negocio total anual global** del ejercicio financiero anterior, optándose por la de mayor cuantía.

---

### 3.7. Matriz Resumen: Coste de Protección WORM vs. Riesgo de Sanción

| Concepto | Con Esta Arquitectura IaC (WORM Locked) | Sin WORM (Almacenamiento Estándar Mutable) |
| :--- | :--- | :--- |
| **Inmutabilidad y No Manipulación** | **Criptográficamente garantizada por el hypervisor de Azure** | Inexistente (modificable por admins, ransomware o bugs) |
| **Coste de Almacenamiento (1 TB / 6 años)** | **~390,96 € totales** (~5,43 €/mes en ZRS) | ~1.680 € (Hot estándar) |
| **Multa Art. 201 bis LGT (AEAT)** | **0 €** (Sistema cumple directivas de inalterabilidad) | **Hasta 200.000 €** (50.000 € / ejercicio × 4 años) |
| **Sanción por Falta de Custodia (Art. 201 LGT)**| **0 €** (Retención garantizada de 2.190 días) | **2% al 5% de la facturación inspeccionada** |
| **Riesgo de Pérdida de Deducciones de IVA/IS** | **0 €** (Evidencia original certificada) | **Cuota íntegra deducida + Intereses + Sanción 50-150%** |
| **Impacto en Auditoría Financiera** | **Opinión Limpia** sobre integridad de almacenamiento | **Salvedades / Denegación de Opinión** |
| **Responsabilidad Personal Administradores** | **Blindaje legal** frente a acusaciones de dolo/negligencia | **Riesgo de concurso culpable y embargo patrimonial** |

---

## 4. Certificaciones de Azure Spain Central

Microsoft Azure opera sus centros de datos de la región Spain Central bajo los siguientes esquemas de cumplimiento validados por auditores independientes:
* **ENS (Esquema Nacional de Seguridad) - Categoría ALTO**: Certificado oficial emitido por BSI / CCN-CERT.
* **ISO/IEC 27001, 27017, 27018, 27701**: Seguridad de la información, seguridad en la nube y privacidad de datos personales.
* **SOC 1, SOC 2, SOC 3**: Informes de controles en organizaciones de servicios para auditorías financieras y operativas.

---

## 5. Referencias Oficiales y Publicaciones en Boletines Oficiales

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

