# Guía Operativa Paso a Paso en Azure Portal (Operación Manual / ClickOps)

---

### 🧭 Navegación de la Documentación
| 🏠 [Inicio / README](../README.md) | 🏛️ [Arquitectura](ARCHITECTURE.md) | ⚖️ [Marco Legal](LEGAL_COMPLIANCE_SPAIN.md) | 💰 [Optimización de Costes](COST_OPTIMIZATION.md) | 🔒 [Guía WORM Lock](WORM_POLICY_LOCK_GUIDE.md) | 🖱️ **Manual Portal** | 📊 [Auditoría & KQL](AUDITING_AND_MONITORING.md) | 🔌 [Integración ERP](ERP_INTEGRATION_AND_REHYDRATION.md) | 🚀 [Guía CI/CD](CICD_AUTOMATION_GUIDE.md) |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |

---

Esta guía detalla minuciosamente el procedimiento manual (*ClickOps*) paso a paso a través de la interfaz gráfica del **Portal de Azure** ([portal.azure.com](https://portal.azure.com)). Se incluyen los nombres exactos tanto en **Español** como en **Inglés** de cada campo, botón y pestaña, junto con la justificación técnica, legal y financiera de cada decisión.

---

## 📋 Requisitos Previos / Prerequisites
* Suscripción activa de **Microsoft Azure** con rol de `Propietario (Owner)` o `Colaborador (Contributor)`.
* Permisos para aprovisionar recursos en la región **Spain Central (Madrid)**.

---

## 📑 Índice de Fases Operativas

1. [Fase 1: Creación del Grupo de Recursos (Resource Group)](#fase-1-creación-del-grupo-de-recursos-resource-group)
2. [Fase 2: Despliegue de la Cuenta de Almacenamiento (Storage Account)](#fase-2-despliegue-de-la-cuenta-de-almacenamiento-storage-account)
3. [Fase 3: Configuración de Protección de Datos (Soft Delete & Versionado)](#fase-3-configuración-de-protección-de-datos-soft-delete--versionado)
4. [Fase 4: Creación de los Contenedores ERP (`facturas` y `pedidos`)](#fase-4-creación-de-los-contenedores-erp-facturas-y-pedidos)
5. [Fase 5: Configuración de la Directiva Inmutable WORM (2.190 días / 6 años)](#fase-5-configuración-de-la-directiva-inmutable-worm-2190-días--6-años)
6. [Fase 6: Configuración de Ciclo de Vida Automatizado (Lifecycle Tiering)](#fase-6-configuración-de-ciclo-de-vida-automatizado-lifecycle-tiering)
7. [Fase 7: Aplicación del Bloqueo de Recurso Antiransomware (`CanNotDelete`)](#fase-7-aplicación-del-bloqueo-de-recurso-antiransomware-cannotdelete)
8. [Fase 8: Verificación Práctica de Ingesta y Bloqueo Definitivo en Producción](#fase-8-verificación-práctica-de-ingesta-y-bloqueo-definitivo-en-producción)
9. [Resumen de Verificación Rápida](#-resumen-de-verificación-rápida)
10. [Navegación entre Módulos de Documentación](#-navegación-entre-módulos)

---

## Fase 1: Creación del Grupo de Recursos (Resource Group)

### ¿Por qué este paso?
Un grupo de recursos dedicado permite aislar los datos contables del ERP, establecer límites de control de acceso RBAC específicos para el equipo financiero y auditar costes de forma segregada.

### Pasos en el Portal:
1. Inicie sesión en [portal.azure.com](https://portal.azure.com).
2. En la barra de búsqueda superior, escriba **Grupos de recursos** (*Resource groups*) y selecciónelo.
3. Haga clic en el botón superior **+ Crear** (*+ Create*).
4. En la pestaña **Datos básicos** (*Basics*):
   * **Suscripción** (*Subscription*): Seleccione su suscripción corporativa.
   * **Grupo de recursos** (*Resource group*): Escriba `rg-erp-storage-prod-spaincentral`.
   * **Región** (*Region*): Seleccione **(Europe) Spain Central** / **(Europa) España Central**.
5. Vaya a la pestaña **Etiquetas** (*Tags*) y agregue:
   * `Workload` $\rightarrow$ `ERP-Document-Archive`
   * `LegalCompliance` $\rightarrow$ `Codigo-de-Comercio-Art30-VeriFactu`
   * `Country` $\rightarrow$ `Spain`
   * `CostCenter` $\rightarrow$ `Finance-IT`
6. Haga clic en **Revisar y crear** (*Review + create*), espere la validación verde y haga clic en **Crear** (*Create*).

---

## Fase 2: Despliegue de la Cuenta de Almacenamiento (Storage Account)

### ¿Por qué este paso?
La cuenta debe ser de tipo *General Purpose v2* (`StorageV2`) para soportar los 4 niveles de acceso (Hot, Cool, Cold, Archive) y directivas WORM. Seleccionamos **ZRS** (Zone-Redundant Storage) para garantizar supervivencia ante la caída completa de un centro de datos en Madrid.

### Pasos en el Portal:
1. Abra el grupo de recursos `rg-erp-storage-prod-spaincentral`.
2. Haga clic en **+ Crear** (*+ Create*) o **+ Agregar** (*+ Add*).
3. Busque **Cuenta de almacenamiento** (*Storage account*) y haga clic en **Crear** (*Create*).

#### 1. Pestaña Datos básicos (*Basics*)
```text
+----------------------------------------------------------------------------------+
| Suscripción / Subscription        : [ Su suscripción corporativa ]               |
| Grupo de recursos / Resource group: rg-erp-storage-prod-spaincentral             |
| Nombre de cuenta / Account name   : sterpprod<sufijo_unico> (3-24 letras/números)|
| Región / Region                   : (Europe) Spain Central                       |
| Rendimiento / Performance         : Estándar (Standard)                          |
| Redundancia / Redundancy          : Zone-redundant storage (ZRS)                 |
+----------------------------------------------------------------------------------+
```
> [!TIP]
> **ZRS vs LRS**: En Spain Central, ZRS distribuye los datos sincrónicamente en tres zonas de disponibilidad físicas independientes (distintos edificios, acometidas eléctricas y redes en Madrid). En entornos de prueba o dev puede elegir **LRS** (*Locally redundant storage*) para un coste ligeramente menor.

#### 2. Pestaña Opciones avanzadas (*Advanced*)
* **Seguridad / Security**:
  * **Requerir transferencia segura para las operaciones de la API REST** (*Require secure transfer*): **Marcado** (Fuerza HTTPS).
  * **Habilitar cifrado de infraestructura** (*Enable infrastructure encryption*): Opcional (doble cifrado a nivel de hardware y servicio).
  * **Permitir habilitar el acceso público en contenedores individuales** (*Allow enabling public access*): **DESMARCADO / UNCHECKED**.
    *(⚠️ Crítico: Garantiza que ningún usuario pueda exponer facturas de forma anónima en internet).*
  * **Habilitar acceso con clave de cuenta de almacenamiento** (*Enable storage account key access*): Marcado (o desmarcado si usa exclusivamente Microsoft Entra ID RBAC).
  * **Versión mínima de TLS** (*Minimum TLS version*): **Version 1.2**.
  * **Nivel de acceso predeterminado** (*Access tier*): **Frecuente (Hot)**.
    *(Las facturas del día a día se leen con coste cero por GB; el ciclo de vida las moverá automáticamente después).*

#### 3. Pestaña Redes (*Networking*)
* **Acceso de red** (*Network access*):
  * *Para pruebas iniciales*: **Habilitar acceso público desde todas las redes** (*Enable public access from all networks*).
  * *Para producción endurecida*: **Habilitar acceso público desde redes virtuales y direcciones IP seleccionadas** (*Enable public access from selected virtual networks and IP addresses*) y añada la IP pública de salida de los servidores del ERP.
* **Preferencia de enrutamiento** (*Routing preference*): **Enrutamiento de red de Microsoft** (*Microsoft network routing*).

#### 4. Pestaña Protección de datos (*Data protection*)
Configure los siguientes valores de seguridad:
* **Recuperación / Recovery**:
  * **Habilitar la eliminación temporal de blobs** (*Enable soft delete for blobs*): **Marcado**, establecer en **30 días**.
  * **Habilitar la eliminación temporal de contenedores** (*Enable soft delete for containers*): **Marcado**, establecer en **30 días**.
* **Seguimiento / Tracking**:
  * **Activar el control de versiones de blobs** (*Turn on versioning for blobs*): **Marcado**.
  * **Activar la fuente de cambios de blobs** (*Turn on blob change feed*): **Marcado**.

#### 5. Revisar y Crear (*Review + create*)
* Haga clic en **Revisar** y luego en **Crear**. La implementación tomará entre 1 y 2 minutos.

---

## Fase 3: Configuración de Protección de Datos (Soft Delete & Versionado)

*(Verificación en caso de no haberse configurado en el asistente)*:
1. Abra la cuenta de almacenamiento creada (ej. `sterpspainprod01`).
2. En el menú lateral izquierdo, bajo la sección **Administración de datos** (*Data management*), haga clic en **Protección de datos** (*Data protection*).
3. Asegúrese de que figure:
   * Eliminación temporal de blobs: **30 días**.
   * Eliminación temporal de contenedores: **30 días**.
   * Control de versiones de blobs: **Habilitado**.
   * Fuente de cambios de blobs: **Habilitado**.
4. Si realizó cambios, haga clic en **Guardar** (*Save*) en la parte superior.

---

## Fase 4: Creación de los Contenedores ERP (`facturas` y `pedidos`)

### ¿Por qué este paso?
La separación lógica en contenedores dedicados permite aplicar reglas de ciclo de vida e inmutabilidad con límites claros para los diferentes tipos de documentos del negocio.

### Pasos en el Portal:
1. En el menú lateral de la cuenta de almacenamiento, bajo **Almacenamiento de datos** (*Data storage*), haga clic en **Contenedores** (*Containers*).
2. Haga clic en el botón superior **+ Contenedor** (*+ Container*):
   * **Nombre** (*Name*): `facturas`
   * **Nivel de acceso público** (*Public access level*): **Privado (sin acceso anónimo)** (*Private - no anonymous access*).
   * Haga clic en **Crear** (*Create*).
3. Vuelva a hacer clic en **+ Contenedor**:
   * **Nombre** (*Name*): `pedidos`
   * **Nivel de acceso público** (*Public access level*): **Privado (sin acceso anónimo)**.
   * Haga clic en **Crear** (*Create*).

---

## Fase 5: Configuración de la Directiva Inmutable WORM (2.190 días / 6 años)

### ¿Por qué este paso?
El **Artículo 30 del Código de Comercio** exige la conservación inalterada de facturas y libros durante 6 años. La **Ley Antifraude 11/2021** y el **Reglamento VeriFactu (RD 1007/2023)** exigen que el sistema informático impida la modificación, borrado o interpolación no trazable de las facturas.

### Pasos para el Contenedor `facturas`:
1. En la lista de contenedores, haga clic sobre el nombre **`facturas`**.
2. En el menú secundario izquierdo, bajo la sección **Configuración** (*Settings*), haga clic en **Directiva de acceso** (*Access policy*).
3. Busque la sección **Almacenamiento de blobs inmutable** (*Immutable blob storage*).
4. Haga clic en **+ Agregar directiva** (*+ Add policy*).
5. Se abrirá un panel lateral. Configure exactamente:
   * **Tipo de directiva** (*Policy type*): **Retención basada en tiempo** (*Time-based retention*).
   * **Período de retención** (*Retention period*): Escriba **`2190`** (días). *(6 años $\times$ 365 días = 2.190 días)*.
   * **Permitir escrituras adicionales de anexión** (*Allow additional append writes*): **MARQUE ESTA CASILLA**.
     *(⚠️ Vital: Permite al ERP anexar nuevos bloques o registros hash de auditoría VeriFactu a blobs existentes sin permitir alterar los datos ya grabados).*
6. Haga clic en **Guardar** (*Save*).
7. La directiva quedará guardada en estado **Desbloqueado (Unlocked)**.

### Repita el proceso para el contenedor `pedidos`:
* Repita los pasos del 1 al 6 seleccionando el contenedor `pedidos`.

```text
+---------------------------------------------------------------------------------------+
| ESTADOS DE LA DIRECTIVA WORM:                                                         |
|                                                                                       |
|  [UNLOCKED / DESBLOQUEADO] (Estado inicial configurado):                              |
|  -> Los blobs ya NO pueden ser modificados ni borrados.                               |
|  -> Si cometió un error en el nombre o días, el administrador PUEDE borrar la regla.  |
|                                                                                       |
|  [LOCKED / BLOQUEADO] (Pase definitivo a producción):                                 |
|  -> Irreversible durante 2.190 días.                                                  |
|  -> NI EL ADMINISTRADOR GLOBAL NI EL SOPORTE DE MICROSOFT PUEDEN DESHACERLO.          |
+---------------------------------------------------------------------------------------+
```

---

## Fase 6: Configuración de Ciclo de Vida Automatizado (Lifecycle Tiering)

### ¿Por qué este paso?
Permite reducir el coste de 1 TB de facturas de ~19 €/mes a tan solo ~4,37 € – 5,43 €/mes moviendo automáticamente los documentos a niveles de almacenamiento más económicos a medida que envejecen.

### Pasos en el Portal:
1. Regrese a la vista principal de la Cuenta de Almacenamiento.
2. En el menú lateral izquierdo, bajo **Administración de datos** (*Data management*), haga clic en **Administración del ciclo de vida** (*Lifecycle management*).
3. Haga clic en la pestaña superior **Agregar una regla** (*Add a rule*).

#### 1. Pestaña Detalles (*Details*)
* **Nombre de la regla** (*Rule name*): `tier-erp-invoices-and-orders`
* **Ámbito de la regla** (*Rule scope*): Seleccione **Limitar blobs con filtros** (*Limit blobs with filters*).
* **Tipo de blob** (*Blob type*): Marque **Blobs en bloques** (*Block blobs*).
* **Subtipo de blob** (*Blob subtype*): Marque:
  * [x] **Blobs base** (*Base blobs*)
  * [x] **Instantáneas** (*Snapshots*)
  * [x] **Versiones** (*Versions*)
* Haga clic en **Siguiente** (*Next*).

#### 2. Pestaña Blobs base (*Base blobs*)
Configure las tres transiciones automáticas:
* [x] **Mover a almacenamiento esporádico** (*Move to cool storage*):
  * Días después de la última modificación: **`90`**
* [x] **Mover a almacenamiento en frío** (*Move to cold storage*):
  * Días después de la última modificación: **`365`**
* [x] **Mover a almacenamiento de archivo** (*Move to archive storage*):
  * Días después de la última modificación: **`1095`** *(3 años)*
* Haga clic en **Siguiente** (*Next*).

#### 3. Pestaña Instantáneas (*Snapshots*)
* [x] Mover a almacenamiento esporádico: **`90`** días después de la creación.
* [x] Mover a almacenamiento en frío: **`365`** días después de la creación.
* [x] Mover a almacenamiento de archivo: **`1095`** días después de la creación.
* Haga clic en **Siguiente** (*Next*).

#### 4. Pestaña Versiones (*Versions*)
* [x] Mover a almacenamiento esporádico: **`90`** días después de la creación.
* [x] Mover a almacenamiento en frío: **`365`** días después de la creación.
* [x] Mover a almacenamiento de archivo: **`1095`** días después de la creación.
* Haga clic en **Siguiente** (*Next*).

#### 5. Pestaña Conjunto de filtros (*Filter set*)
Especifique los prefijos para que la regla solo aplique a los contenedores ERP:
* En **Prefijo de blob** (*Blob prefix*), agregue:
  * `facturas/`
  * `pedidos/`
* Haga clic en el botón inferior **Agregar** (*Add*).

---

## Fase 7: Aplicación del Bloqueo de Recurso Antiransomware (`CanNotDelete`)

### ¿Por qué este paso?
Impide que scripts automáticos, cuentas de servicio comprometidas o errores humanos eliminen la cuenta de almacenamiento completa.

### Pasos en el Portal:
1. En el menú lateral izquierdo de la cuenta de almacenamiento, bajo **Configuración** (*Settings*), haga clic en **Bloqueos** (*Locks*).
2. Haga clic en **+ Agregar** (*+ Add*).
3. Rellene el formulario:
   * **Nombre del bloqueo** (*Lock name*): `lock-erp-storage-prevent-deletion`
   * **Tipo de bloqueo** (*Lock type*): Seleccione **Eliminar** (*Delete* - técnicamente `CanNotDelete`).
   * **Notas** (*Notes*): `Protege la cuenta de facturación y pedidos ERP contra borrado accidental o ransomware conforme a normativa fiscal.`
4. Haga clic en **Aceptar** (*OK*).

---

## Fase 8: Verificación Práctica de Ingesta y Bloqueo Definitivo en Producción

### 1. Prueba de Ingesta y Verificación de Inmutabilidad WORM
1. Vaya a **Contenedores** $\rightarrow$ haga clic en **`facturas`**.
2. Haga clic en **Cargar** (*Upload*) y suba un archivo PDF de prueba (ej. `factura_test_001.pdf`).
3. Una vez cargado, haga clic en la casilla de selección del archivo y pulse el botón superior **Eliminar** (*Delete*).
4. Confirme el borrado. Observe el resultado inmediato:
   ```text
   Error al eliminar 1 de 1 blob(s):
   La operación no está permitida debido a una directiva de retención basada en tiempo.
   Código de error: BlobImmutableDueToPolicy (HTTP 409 Conflict)
   ```
   *El almacenamiento WORM ha impedido el borrado con éxito.*

### 2. Bloqueo Permanente de Producción (*Lock Policy*)

> [!CAUTION]
> **ADVERTENCIA FINAL: ACCIÓN PERMANENTE E IRREVERSIBLE**
> 
> Una vez bloqueada la directiva, nadie en el mundo (ni el CEO, ni el Administrador de Dominio, ni el soporte técnico global de Microsoft Azure) podrá desbloquearla ni acortar los 2.190 días. Ejecute esto únicamente cuando las pruebas de ingesta de su ERP hayan finalizado.

1. Vaya a **Contenedores** $\rightarrow$ `facturas` $\rightarrow$ **Directiva de acceso** (*Access policy*).
2. En la fila de la directiva de retención de 2.190 días, haga clic en el botón de tres puntos **`...`** (a la derecha).
3. Seleccione la opción **Bloquear directiva** (*Lock policy*).
4. En el cuadro de diálogo de advertencia, marque la casilla de confirmación y haga clic en **Bloquear directiva** (*Lock policy*).
5. El estado cambiará de **Desbloqueado (Unlocked)** a **Bloqueado (Locked)**.
6. Repita para el contenedor `pedidos`.

---

## 🛠️ Resumen de Verificación Rápida

| Componente | Configuración en Portal | Valor Verificado |
| :--- | :--- | :--- |
| **Región** | Datos básicos $\rightarrow$ Región | `Spain Central` (Madrid) |
| **Redundancia** | Datos básicos $\rightarrow$ Redundancia | `Zone-redundant storage (ZRS)` |
| **Seguridad TLS** | Opciones avanzadas $\rightarrow$ TLS | `TLS 1.2` (mínimo) |
| **Acceso Público** | Opciones avanzadas $\rightarrow$ Acceso público | `Deshabilitado` (Disabled) |
| **Soft Delete** | Protección de datos $\rightarrow$ Eliminación temporal | `30 días` (blobs y contenedores) |
| **Inmutabilidad WORM** | Contenedores $\rightarrow$ Directiva de acceso | `2.190 días` + Append Writes activado |
| **Tiering** | Administración del ciclo de vida $\rightarrow$ Reglas | 90d (Cool), 365d (Cold), 1095d (Archive) |
| **Bloqueo Azure** | Configuración $\rightarrow$ Bloqueos | `CanNotDelete` activado |

---

## 🧭 Navegación entre Módulos

* ⬅️ **Anterior**: [Guía Operativa del Bloqueo WORM (Policy Lock)](WORM_POLICY_LOCK_GUIDE.md)
* 🏠 **Inicio**: [README Principal](../README.md)
* ➡️ **Siguiente**: [Auditoría, Monitorización y Consultas KQL](AUDITING_AND_MONITORING.md)
* 📑 **Índice Completo de Documentación**:
  1. 🏛️ [Arquitectura Técnica](ARCHITECTURE.md)
  2. ⚖️ [Marco Legal y Cumplimiento Normativo (España y UE)](LEGAL_COMPLIANCE_SPAIN.md)
  3. 💰 [Análisis Financiero y Optimización de Costes (TCO)](COST_OPTIMIZATION.md)
  4. 🔒 [Guía Operativa del Bloqueo WORM (Policy Lock)](WORM_POLICY_LOCK_GUIDE.md)
  5. 🖱️ **Manual Paso a Paso en Azure Portal (ClickOps)** (Documento actual)
  6. 📊 [Auditoría, Monitorización y Consultas KQL](AUDITING_AND_MONITORING.md)
  7. 🔌 [Guía de Integración ERP y Rehidratación](ERP_INTEGRATION_AND_REHYDRATION.md)
  8. 🚀 [Automatización CI/CD Multiplataforma](CICD_AUTOMATION_GUIDE.md)

