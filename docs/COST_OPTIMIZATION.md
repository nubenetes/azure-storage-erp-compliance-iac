# Análisis Financiero y Optimización de Costes: Azure Blob Storage ERP (1 TB)

---

### 🧭 Navegación de la Documentación
| 🏠 [Inicio / README](../README.md) | 🏛️ [Arquitectura](ARCHITECTURE.md) | ⚖️ [Marco Legal](LEGAL_COMPLIANCE_SPAIN.md) | 💰 **Optimización de Costes** | 🔒 [Guía WORM Lock](WORM_POLICY_LOCK_GUIDE.md) | 🖱️ [Manual Portal](AZURE_PORTAL_CLICKOPS_GUIDE.md) | 📊 [Auditoría & KQL](AUDITING_AND_MONITORING.md) | 🔌 [Integración ERP](ERP_INTEGRATION_AND_REHYDRATION.md) | 🚀 [Guía CI/CD](CICD_AUTOMATION_GUIDE.md) |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |

---

Este documento proporciona la justificación financiera, matemática y operativa de la arquitectura de niveles de acceso (*access tiering*) en la región **Spain Central (Madrid)** en comparación con los patrones de almacenamiento tradicionales.

---

## 📑 Tabla de Contenidos
1. [Comparativa de Precios Regionales (Spain Central vs. West Europe vs. North Europe)](#1-comparativa-de-precios-regionales-spain-central-vs-west-europe-vs-north-europe)
2. [Modelo Matemático de TCO para 1 TB de Facturas y Pedidos ERP](#2-modelo-matemático-de-tco-para-1-tb-de-facturas-y-pedidos-erp)
   * 2.1. [Hipótesis de Cálculo](#hipótesis-de-cálculo)
   * 2.2. [Distribución de Datos en Estado Estable (Año 6)](#distribución-de-datos-en-estado-estable-año-6)
3. [Comparativa de Costes: Tradicional 100% Hot vs. Ciclo de Vida Automatizado](#3-comparativa-de-costes-tradicional-100-hot-vs-ciclo-de-vida-automatizado)
   * 3.1. [Escenario A: Enfoque Tradicional (100% Nivel Frecuente / Hot)](#escenario-a-enfoque-tradicional-100-nivel-frecuente--hot)
   * 3.2. [Escenario B: Ciclo de Vida Automatizado con 4 Niveles](#escenario-b-ciclo-de-vida-automatizado-con-4-niveles-esta-arquitectura)
4. [Resumen de Ahorro Financiero](#4-resumen-de-ahorro-financiero)
5. [Análisis Detallado de Costes de Rehidratación y Ejemplos Prácticos](#5-análisis-detallado-de-costes-de-rehidratación-y-ejemplos-prácticos)
   * 5.1. [Estructura y Componentes de Coste de Rehidratación en Spain Central](#51-estructura-y-componentes-de-coste-de-rehidratación-en-spain-central)
   * 5.2. [Ejemplo 1: Inspección Tributaria Ordinaria de la AEAT (100 GB / ~20.000 Facturas)](#ejemplo-1-inspección-tributaria-ordinaria-de-la-aeat-100-gb--20000-facturas)
   * 5.3. [Ejemplo 2: Requerimiento Judicial Urgente (50 GB con Alta Prioridad < 1h)](#ejemplo-2-requerimiento-judicial-urgente-50-gb-con-alta-prioridad--1h)
   * 5.4. [Ejemplo 3: Consulta Unitaria de Factura Aislada (1 Factura / 2 MB)](#ejemplo-3-consulta-unitaria-de-factura-aislada-1-factura--2-mb)
   * 5.5. [Ejemplo 4: Rehidratación Prematura y Penalización por Retiro Anticipado](#ejemplo-4-rehidratación-prematura-y-penalización-por-retiro-anticipado-early-deletion)
   * 5.6. [Matriz Comparativa: Coste de Rehidratación vs. Ahorro de Custodia Acumulado](#56-matriz-comparativa-coste-de-rehidratación-vs-ahorro-de-custodia-acumulado)
6. [Navegación entre Módulos de Documentación](#-navegación-entre-módulos)

---

---

### 🎥 Recursos Audiovisuales y Guías de FinOps en YouTube
Este análisis financiero y el modelo TCO se complementan con videotutoriales técnicos sintetizados con **Gemini NotebookLM** en el canal [**@nubenetes**](https://youtube.com/@nubenetes):
- 📽️ [**Azure ERP: Más del 75% de Ahorro FinOps con Ciclo de Vida y Storage WORM**](https://www.youtube.com/watch?v=Ck36Qyz0QJs) (`6:00`) — *Desglose matemático del TCO de 1 TB, progresión Hot a Archive y ahorro neto del 75%.*
- 📽️ [**Coste y Estrategia de Rehidratación en Azure WORM: De Archive a Auditoría**](https://www.youtube.com/watch?v=RoGpL_4YGkA) (`7:34`) — *Cálculos de rehidratación por lote de 100 GB, prioridades Estándar vs Alta y retención WORM.*
- ⚡ [**Cómo Archivar Facturas Seis Años en Azure sin Arruinarte**](https://www.youtube.com/shorts/7ZerGBHznr8) (`1:08`) — *Píldora rápida de 1 minuto resumiendo el ciclo de vida en 4 niveles y el cumplimiento legal.*

---

## 1. Comparativa de Precios Regionales (Spain Central vs. West Europe vs. North Europe)

Precios oficiales de referencia en Euros (€) para cuentas *Standard General Purpose v2*:

| Nivel de Acceso | Spain Central (`spaincentral`) | West Europe (`westeurope`) | North Europe (`northeurope`) | Notas |
| :--- | :--- | :--- | :--- | :--- |
| **Frecuente / Hot (LRS)** | ~0,0184 € / GB / mes | ~0,0184 € / GB / mes | ~0,0184 € / GB / mes | Mismo precio de lista |
| **Frecuente / Hot (ZRS)** | ~0,0230 € / GB / mes | ~0,0230 € / GB / mes | ~0,0230 € / GB / mes | Redundancia de zona (3 AZs en Madrid) |
| **Esporádico / Cool (LRS)** | ~0,0100 € / GB / mes | ~0,0100 € / GB / mes | ~0,0100 € / GB / mes | **~46% de ahorro** |
| **Frío / Cold (LRS)** | ~0,0045 € / GB / mes | ~0,0045 € / GB / mes | ~0,0045 € / GB / mes | **~76% de ahorro** |
| **Archivo / Archive (LRS)**| ~0,00099 € / GB / mes| ~0,00099 € / GB / mes| ~0,00099 € / GB / mes| **~95% de ahorro** |
| **Salida de Red (España)** | **< 10 ms (intra-país)** | 30-45 ms (transfronterizo) | 35-50 ms (transfronterizo) | Cero penalización de latencia, enrutamiento local |

> [!NOTE]
> Microsoft Azure factura exactamente el mismo precio base de almacenamiento en **Spain Central (Madrid)** que en Ámsterdam o Dublín. Elegir Spain Central aporta ventajas directas en latencia, cumplimiento de soberanía de datos y ningún sobrecoste por región.

---

## 2. Modelo Matemático de TCO para 1 TB de Facturas y Pedidos ERP

### Hipótesis de Cálculo
* **Volumen Acumulado en Régimen Permanente**: 1.000 GB (1 TB) acumulados a lo largo de 6 años de actividad empresarial.
* **Ingesta Mensual Promedio**: ~13,88 GB de nuevas facturas y pedidos al mes (~166,6 GB al año).
* **Periodo de Retención Documental**: 6 años (2.190 días) en virtud del Artículo 30 del Código de Comercio español.
* **Modelo de Redundancia**: Los cálculos se presentan comparando LRS y ZRS.

### Distribución de Datos en Estado Estable (Año 6)

```text
Volumen Total = 1.000 GB
├── Nivel Hot / Frecuente (Días 0 - 90, 3 meses):     41,67 GB  (4,17%)
├── Nivel Cool / Esporádico (Días 91 - 365, 9 meses): 125,00 GB (12,50%)
├── Nivel Cold / Frío (Años 1 - 3, 24 meses):         333,33 GB (33,33%)
└── Nivel Archive / Archivo (Años 3 - 6, 36 meses):   500,00 GB (50,00%)
```

---

## 3. Comparativa de Costes: Tradicional 100% Hot vs. Ciclo de Vida Automatizado

### Escenario A: Enfoque Tradicional (100% Nivel Frecuente / Hot)
La totalidad del terabyte (1.000 GB) permanece en el nivel *Hot* de forma indefinida.

| Concepto | Mensual (LRS) | Mensual (ZRS) | Coste Anual (LRS) | Coste Anual (ZRS) |
| :--- | :--- | :--- | :--- | :--- |
| 1.000 GB en Nivel Hot | 18,40 € | 23,00 € | 220,80 € | 276,00 € |
| Operaciones de Lectura / Escritura | ~0,40 € | ~0,40 € | 4,80 € | 4,80 € |
| **Coste Total Mensual** | **~18,80 €** | **~23,40 €** | **~225,60 €** | **~280,80 €** |

---

### Escenario B: Ciclo de Vida Automatizado con 4 Niveles (Esta Arquitectura)
Los datos transicionan automáticamente: *Hot* $\rightarrow$ *Cool* $\rightarrow$ *Cold* $\rightarrow$ *Archive*.

| Nivel / Componente | Volumen de Datos | Tarifa LRS (€/GB/mes) | Tarifa ZRS (€/GB/mes) | Coste Mensual (LRS) | Coste Mensual (ZRS) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Hot** (Facturas recientes, 0-90 días) | 41,67 GB | 0,0184 € | 0,0230 € | 0,77 € | 0,96 € |
| **Cool** (Ejercicio fiscal en curso, 91-365 días) | 125,00 GB | 0,0100 € | 0,0125 € | 1,25 € | 1,56 € |
| **Cold** (Plazo prescripción fiscal, 1-3 años) | 333,33 GB | 0,0045 € | 0,0058 € | 1,50 € | 1,93 € |
| **Archive** (Custodia mercantil estatutaria, 3-6 años) | 500,00 GB | 0,00099 € | 0,00125 € | 0,50 € | 0,63 € |
| Operaciones y transiciones de ciclo de vida | ~13,88 GB/mes | - | - | ~0,35 € | ~0,35 € |
| **Coste Total Mensual** | **1.000 GB** | - | - | **~4,37 € / mes** | **~5,43 € / mes** |

---

## 4. Resumen de Ahorro Financiero

| Métrica | Arquitectura Todo-Hot | Ciclo de Vida Automatizado (LRS) | Ciclo de Vida Automatizado (ZRS) |
| :--- | :--- | :--- | :--- |
| **Factura Mensual** | 18,80 € | **4,37 €** | **5,43 €** |
| **Factura Anual** | 225,60 € | **52,44 €** | **65,16 €** |
| **TCO a 6 años (Periodo Legal)** | 1.353,60 € | **314,64 €** | **390,96 €** |
| **Ahorro Absoluto (a 6 años)**| Línea base | **1.038,96 € de ahorro** | **962,64 € de ahorro** |
| **Ahorro Relativo (%)** | Línea base | **76,8% de Reducción** | **71,1% de Reducción (con 3 zonas de disponibilidad)** |

> [!TIP]
> Obsérvese que la arquitectura con **Ciclo de Vida y ZRS** (distribuida en 3 zonas de disponibilidad físicas independientes en Madrid) cuesta **tan solo ~5,43 €/mes**, lo que representa un coste **~71% inferior** al de almacenar los datos en un único centro de datos (LRS) en nivel Hot tradicional.

---

---

## 5. Análisis Detallado de Costes de Rehidratación y Ejemplos Prácticos

El nivel **Archivo (*Archive Tier*)** ofrece un coste de custodia extraordinariamente reducido (**0,00099 €/GB/mes en LRS**, **0,00125 €/GB/mes en ZRS** en Spain Central), pero los datos se encuentran en estado *offline*. Para leer o descargar facturas archivadas es necesario un proceso de **rehidratación** (traslado del blob desde *Archive* a *Cool* o *Hot*).

A continuación se desglosan las tarifas oficiales de Azure para la región **Spain Central (Madrid)** y 4 casos prácticos numéricos que demuestran el coste real de una auditoría o inspección fiscal.

---

### 5.1. Estructura y Componentes de Coste de Rehidratación en Spain Central

El coste total de rehidratar y consultar un lote de facturas se compone de 4 conceptos tarificados por Azure:

$$\text{Coste Total Rehidratación} = C_{\text{recuperación}} + C_{\text{operaciones API}} + C_{\text{almacenamiento temporal}} + C_{\text{penalización anticipada}}$$

| Concepto | Nivel / Modalidad | Tarifa Spain Central (Euros) | Descripción |
| :--- | :--- | :--- | :--- |
| **Recuperación de Datos (*Data Retrieval*)** | **Prioridad Estándar (*Standard*)** | **0,0220 € / GB** | Rehidratación en **3 a 15 horas**. Ideal para requerimientos tributarios ordinarios (plazo legal de 10 días hábiles). |
| **Recuperación de Datos (*Data Retrieval*)** | **Alta Prioridad (*High Priority*)** | **0,1100 € / GB** | Rehidratación en **< 1 hora** (para blobs de hasta 10 GB). Para requerimientos urgentes o inspecciones presenciales. |
| **Transacciones de Cambio de Nivel (*Set Blob Tier*)** | Nivel Archive | **0,055 € por 10.000 operaciones** | Cargo por invocar la API `SetBlobTier` o copiar el blob hacia el nivel en línea. |
| **Lectura de Datos (*Get Blob*)** | Nivel Cool destino | **0,011 € por 10.000 lecturas** | Cargo por la descarga de los ficheros una vez rehidratados. |
| **Almacenamiento Temporal Destino** | Nivel Cool | **0,0100 € / GB / mes** | Facturación prorrateada por los días que el dato permanezca en Cool antes de archivarse de nuevo. |
| **Penalización por Retiro Anticipado (*Early Deletion*)** | Nivel Archive (< 180 días) | Prorrateo diario a **0,00099 € / GB / mes** | Solo aplica si el blob se rehidrata **antes de cumplir 180 días** en el nivel Archive. |

> [!NOTE]
> **Plazos Mínimos de Retención de Azure**:
> * **Archive**: 180 días.
> * **Cold**: 90 días.
> * **Cool**: 30 días.
> Dado que nuestra directiva de ciclo de vida traslada las facturas a *Archive* a los **1.095 días (3 años)** y las conserva hasta los **2.190 días (6 años)**, las facturas permanecen 3 años completos en Archive ($1.095\text{ días} \gg 180\text{ días}$), por lo que **la penalización por retiro anticipado es estrictamente 0,00 €** en operaciones ordinarias de auditoría.

---

### 5.2. Ejemplo 1: Inspección Tributaria Ordinaria de la AEAT (100 GB / ~20.000 Facturas)

**Escenario**: La Agencia Tributaria notifica el inicio de un procedimiento de comprobación del Impuesto sobre Sociedades y solicita la entrega íntegra de las facturas emitidas y recibidas correspondientes al ejercicio fiscal de hace 4 años (año 4 de custodia, alojado en nivel *Archive*).

* **Volumen del Lote**: **100 GB** (equivalente a ~20.000 facturas electrónicas compuestas por PDF de visualización y XML firmado VeriFactu/Facturae, con un tamaño medio de 5 MB por expediente).
* **Prioridad Seleccionada**: **Prioridad Estándar (*Standard Priority*)**. Plazo de rehidratación: 3 a 15 horas (perfectamente compatible con el plazo de cortesía de 10 días concedido por la AEAT).
* **Nivel de Destino**: **Esporádico (*Cool*)**, manteniéndose rehidratado durante **30 días** mientras los inspectores realizan la verificación.

#### Desglose Matemático del Coste:
1. **Recuperación de Datos (*Data Retrieval*)**:
   $$100\text{ GB} \times 0,0220\text{ €/GB} = \mathbf{2,20\text{ €}}$$
2. **Operaciones de API de Rehidratación (`SetBlobTier`)**:
   $$20.000\text{ blobs} \times \left(\frac{0,055\text{ €}}{10.000\text{ ops}}\right) = \mathbf{0,11\text{ €}}$$
3. **Descarga y Lectura de Datos (`GetBlob`)**:
   $$20.000\text{ lecturas} \times \left(\frac{0,011\text{ €}}{10.000\text{ ops}}\right) = \mathbf{0,02\text{ €}}$$
4. **Almacenamiento en Nivel Cool (30 días de inspección)**:
   $$100\text{ GB} \times 0,0100\text{ €/GB/mes} \times \frac{30}{30} = \mathbf{1,00\text{ €}}$$
5. **Penalización por Retiro Anticipado**:
   $$\mathbf{0,00\text{ €}}\quad (\text{las facturas llevan 365 días en Archive, superando los 180 días mínimos})$$

$$\mathbf{\text{Coste Total de la Auditoría AEAT: } 2,20 + 0,11 + 0,02 + 1,00 = 3,33\text{ €}}$$

> [!TIP]
> **Balance Financiero del Ejemplo 1**:
> Mantener esos mismos 100 GB en nivel *Hot* durante los 3 años anteriores habría costado: $100\text{ GB} \times 0,0184\text{ €} \times 36\text{ meses} = \mathbf{66,24\text{ €}}$.
> Al mantenerlos en *Archive* costó: $100\text{ GB} \times 0,00099\text{ €} \times 36\text{ meses} = \mathbf{3,56\text{ €}}$.
> Incluso pagando la rehidratación completa para el auditor (3,33 €), la empresa ha logrado un **ahorro neto de 59,35 €** por cada 100 GB archivados.

---

### 5.3. Ejemplo 2: Requerimiento Judicial Urgente (50 GB con Alta Prioridad < 1h)

**Escenario**: Un Juzgado de lo Mercantil emite un requerimiento judicial cautelar de exhibición urgente de contratos y pedidos de un litigio comercial, concediendo un plazo improrrogable de 3 horas para la entrega de la documentación probatoria.

* **Volumen del Lote**: **50 GB** (~10.000 documentos).
* **Prioridad Seleccionada**: **Alta Prioridad (*High Priority*)**. El hypervisor de Azure garantiza la disponibilidad del fichero en **menos de 60 minutos**.
* **Nivel de Destino**: **Frecuente (*Hot*)**, descargándose de inmediato y retirándose a los 7 días.

#### Desglose Matemático del Coste:
1. **Recuperación de Datos Urgente (*High Priority Retrieval*)**:
   $$50\text{ GB} \times 0,1100\text{ €/GB} = \mathbf{5,50\text{ €}}$$
2. **Operaciones de API (`SetBlobTier`)**:
   $$10.000\text{ blobs} \times \left(\frac{0,055\text{ €}}{10.000\text{ ops}}\right) = \mathbf{0,055\text{ €}}$$
3. **Descarga de Datos (`GetBlob`)**:
   $$10.000\text{ lecturas} \times \left(\frac{0,004\text{ €}}{10.000\text{ ops}}\right) = \mathbf{0,004\text{ €}}$$
4. **Almacenamiento Temporal en Hot (7 días)**:
   $$50\text{ GB} \times 0,0184\text{ €/GB/mes} \times \frac{7}{30} = \mathbf{0,21\text{ €}}$$

$$\mathbf{\text{Coste Total de la Rehidratación Urgente: } 5,50 + 0,055 + 0,004 + 0,21 = 5,77\text{ €}}$$

---

### 5.4. Ejemplo 3: Consulta Unitaria de Factura Aislada (1 Factura / 2 MB)

**Escenario**: Un cliente histórico o el departamento de atención contable solicita una copia de una factura de hace 5 años para cotejar una garantía de producto.

* **Volumen**: 1 factura en formato PDF/A firmado (**2 MB** = $0,00195\text{ GB}$).
* **Prioridad**: **Estándar** (3-15 horas).
* **Nivel de Destino**: **Cool**.

#### Desglose Matemático del Coste:
1. **Recuperación de Datos**:
   $$0,001953\text{ GB} \times 0,0220\text{ €/GB} = \mathbf{0,000043\text{ €}}$$
2. **Transacción API**:
   $$1 \text{ operación} \times \left(\frac{0,055\text{ €}}{10.000}\right) = \mathbf{0,0000055\text{ €}}$$
3. **Almacenamiento en Cool (30 días)**:
   $$0,001953\text{ GB} \times 0,0100\text{ €} = \mathbf{0,000020\text{ €}}$$

$$\mathbf{\text{Coste Total: } \approx 0,00007\text{ € (menos de una centésima de céntimo)}}$$

---

### 5.5. Ejemplo 4: Rehidratación Prematura y Penalización por Retiro Anticipado (*Early Deletion*)

**Escenario**: Por un error de clasificación en el ERP, se trasladó manualmente un lote de facturas de **20 GB** al nivel *Archive*. Al cabo de **45 días**, el departamento financiero detecta el error y ordena devolver las facturas al nivel *Cool* (faltan 135 días para cumplir el compromiso de retención mínima de 180 días de Archive).

#### Desglose Matemático de la Penalización:
* **Tarifa Diaria de Archive (LRS)**:
  $$\frac{0,00099\text{ €/GB/mes}}{30\text{ días}} = 0,000033\text{ € por GB al día}$$
* **Días Restantes Penalizados**: $180 - 45 = \mathbf{135\text{ días}}$.
* **Cargo por Penalización de Retiro Anticipado**:
  $$\text{Penalización} = 20\text{ GB} \times 0,000033\text{ €/GB/día} \times 135\text{ días} = \mathbf{0,089\text{ €}}$$
* **Coste de Recuperación de Datos (Standard)**:
  $$20\text{ GB} \times 0,0220\text{ €/GB} = \mathbf{0,440\text{ €}}$$
* **Operaciones de API**: ~0,011 €.

$$\mathbf{\text{Coste Total de la Operación Prematura: } 0,089 + 0,440 + 0,011 = \mathbf{0,54\text{ €}}}$$

> [!IMPORTANT]
> Incluso en el peor escenario operativo posible (rehidratación prematura antes de los 180 días), el coste de penalización de Azure es de tan solo **~0,09 €**, lo que ratifica la absoluta viabilidad económica de la arquitectura de archivado.

---

### 5.6. Matriz Comparativa: Coste de Rehidratación vs. Ahorro de Custodia Acumulado

| Supuesto Operativo | Volumen / Tamaño | Prioridad | Tiempo de Espera | Coste de Rehidratación (€) | Ahorro Histórico Acumulado (€) | Rentabilidad Neta |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Factura Aislada** | 1 Factura (2 MB) | Estándar | 3 - 15 horas | **< 0,0001 €** | ~0,12 € | **Ahorro > 99%** |
| **Auditoría Trimestral** | 25 GB (~5.000 docs) | Estándar | 3 - 15 horas | **~0,85 €** | ~14,80 € | **Ahorro > 94%** |
| **Inspección Fiscal Anual (AEAT)** | 100 GB (~20.000 docs) | Estándar | 3 - 15 horas | **~3,33 €** | ~59,35 € | **Ahorro > 94%** |
| **Requerimiento Judicial Urgente** | 50 GB (~10.000 docs) | Alta | **< 1 hora** | **~5,77 €** | ~29,70 € | **Ahorro > 80%** |
| **Rehidratación Errónea (< 180d)** | 20 GB (Con penalización) | Estándar | 3 - 15 horas | **~0,54 €** | ~0,50 € | **Coste amortizado** |

---

## 🧭 Navegación entre Módulos

* ⬅️ **Anterior**: [Marco Legal y Cumplimiento Normativo (España y UE)](LEGAL_COMPLIANCE_SPAIN.md)
* 🏠 **Inicio**: [README Principal](../README.md)
* ➡️ **Siguiente**: [Guía Operativa del Bloqueo WORM (Policy Lock)](WORM_POLICY_LOCK_GUIDE.md)
* 📑 **Índice Completo de Documentación**:
  1. 🏛️ [Arquitectura Técnica](ARCHITECTURE.md)
  2. ⚖️ [Marco Legal y Cumplimiento Normativo (España y UE)](LEGAL_COMPLIANCE_SPAIN.md)
  3. 💰 **Análisis Financiero y Optimización de Costes (TCO)** (Documento actual)
  4. 🔒 [Guía Operativa del Bloqueo WORM (Policy Lock)](WORM_POLICY_LOCK_GUIDE.md)
  5. 🖱️ [Manual Paso a Paso en Azure Portal (ClickOps)](AZURE_PORTAL_CLICKOPS_GUIDE.md)
  6. 📊 [Auditoría, Monitorización y Consultas KQL](AUDITING_AND_MONITORING.md)
  7. 🔌 [Guía de Integración ERP y Rehidratación](ERP_INTEGRATION_AND_REHYDRATION.md)
  8. 🚀 [Automatización CI/CD Multiplataforma](CICD_AUTOMATION_GUIDE.md)

