# Análisis Financiero y Optimización de Costes: Azure Blob Storage ERP (1 TB)

Este documento proporciona la justificación financiera, matemática y operativa de la arquitectura de niveles de acceso (*access tiering*) en la región **Spain Central (Madrid)** en comparación con los patrones de almacenamiento tradicionales.

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

## 5. Consideraciones Operativas, Recuperación y Rehidratación de Datos

Al diseñar una política de archivado para facturas de ERP, deben contemplarse los costes transaccionales de recuperación:

1. **Operaciones de Lectura / Descarga**:
   * **Hot (Frecuente)**: Sin coste por recuperación de datos. Óptimo para descargas habituales desde el portal de clientes o la consulta diaria de contabilidad.
   * **Cool (Esporádico)**: Tarifa de lectura reducida (~0,01 € por GB recuperado). Despreciable para revisiones trimestrales o cierres anuales.
   * **Cold (Frío)**: Tarifa de recuperación intermedia (~0,03 € por GB). Altamente rentable para auditorías fiscales que ocurren esporádicamente una vez cada varios años.
   * **Archive (Archivo)**: Tarifa de rehidratación (~0,022 € por GB) + latencia de desbloqueo (Prioridad Estándar: 3-15 horas; Alta Prioridad: < 1 hora). Dado que las facturas de más de 3 años de antigüedad prácticamente nunca se consultan salvo inspección tributaria formal, mantener 500 GB en Archive ahorra ~8,70 €/mes, mientras que rehidratar 10 GB para una inspección cuesta menos de 0,25 €.
2. **Operaciones de Transición de Ciclo de Vida**:
   * Mover blobs entre niveles genera un coste de operación de escritura por cada 10.000 blobs (~0,05 € - 0,10 €). Para un volumen de ~10.000 facturas mensuales, los cargos de transición equivalen a menos de 0,10 €/mes.
3. **Plazos Mínimos de Retención por Nivel**:
   * Cool: 30 días de retención mínima.
   * Cold: 90 días de retención mínima.
   * Archive: 180 días de retención mínima.
   * *Nuestras reglas de ciclo de vida mueven los datos a los 90 días, 365 días y 1.095 días, superando holgadamente los límites mínimos exigidos por Azure y evitando penalizaciones por eliminación anticipada.*
