# Plan de Trabajo y Tareas Pendientes - FlexiSuite

Este documento sirve como nuestra guía central para el desarrollo, seguimiento de tareas y registro de lecciones aprendidas.

**IMPORTANTE: Al reiniciar sesión, lee primero este archivo completo para conocer el estado actual del proyecto.**

---

## ✅ Avances y Tareas Completadas (18 Nov 2025)

### 🎉 Portal Admin: Generación de Cargos de Cuotas (NUEVO - 18 Nov 2025)

**Screen:** `/flexisuite_portal/lib/screens/fee_charge_generation_screen.dart`

**Funcionalidad Implementada:**
- ✅ **Arquitectura de 3 paneles master-detail:**
  - Panel 1 (Izquierda): Lista de Fees/Cuotas con contador de asignaciones
  - Panel 2 (Centro): Asignaciones de residentes al fee seleccionado
  - Panel 3 (Derecha): Cargos generados del residente seleccionado
  
- ✅ **CRUD de Fees - Modal Unificado:**
  - Modal único `_showFeeModal({fee})` que sirve para crear Y editar
  - Si recibe `fee` → modo edición, si no → modo creación
  - **Toggle Buttons** para tipo: Recurrente vs Única vez
  - **Fechas condicionales:** 
    - Recurrente: 2 cards (Válida desde + Válida hasta opcional)
    - Única vez: 1 card (fecha única que se copia a inicio y fin)
  - Campos: Nombre, Monto, Día de cargo (1-31), Descripción
  - Modal estilo PC: 700px ancho, 2 columnas, cards clicables, OutlineInputBorder
  - Validaciones completas en todos los campos
  - Debug logging detallado con stacktrace
  
- ✅ **Selección Visual y Estados:**
  - Cards con color de fondo al seleccionar (fee, asignación)
  - Indicadores visuales: ✅ activo / ⭕ inactivo (por fechas)
  - Botón editar (✏️) solo aparece si el fee tiene 0 asignaciones
  - Limpieza automática de paneles al cambiar selección
  
- ✅ **Carga de Datos con Filtrado de Nulos:**
  - Queries optimizados: consultas separadas + Map joining (no joins complejos)
  - Filtrado `.where((id) => id != null)` para evitar errores de UUID inválido
  - Validación de arrays vacíos antes de `.inFilter()`
  - Mounted checks antes de cada setState()
  
- ✅ **Panel de Cargos Mejorado:**
  - Ordenamiento por fecha descendente (más recientes primero)
  - Información completa: Fecha de cargo, Ubicación, Fecha de pago
  - Formato visual mejorado: Cards, badges de estado, emojis
  - Diferenciación clara: Pendiente (naranja) / Pagado (verde)
  
- ✅ **RLS Policies Configuradas:**
  - Políticas permisivas en: fees, user_location_fees, user_fee_charges, locations, users
  - Patrón: `FOR ALL USING (true) WITH CHECK (true)` (temporal para desarrollo)
  
- ✅ **Registro de Feature:**
  - Feature code: `cuota_generar_cargo`
  - SQL: `/flexisuite_app/SQLs/add_fee_charge_generation_feature.sql`
  - Registrado en 3 planes con role: admin
  - Navegación agregada en `main_screen.dart`
  
- ✅ **Traducciones i18n COMPLETAS:**
  - Namespace `feeChargeGeneration` en 5 idiomas (es, en, fr, pt, de)
  - 25+ claves traducidas en TODAS las pantallas
  - **Portal:** Menú principal actualizado con traducciones
  - **App:** Menú principal actualizado con traducciones
  - Textos de UI, botones, modals, mensajes de error
  - Uso de `I18nProvider` en todos los widgets
  
- ✅ **Formateo de Moneda:**
  - Implementado sistema de formateo dinámico de moneda
  - Detecta símbolo de moneda de la organización
  - Formato correcto según locale (comas, puntos, separadores)
  - Aplicado en: montos de fees, cargos, pagos
  - Pattern: `NumberFormat.currency(locale: 'es_MX', symbol: '\$')`

**Base de Datos:**
- `fees`: id, organization_id, name, amount, description, default_day, is_recurring, valid_from, valid_to, fee_type(bigint-unused)
- `user_location_fees`: id, user_id, organization_id, location_id, fee_id, valid_from, valid_to, is_active
- `user_fee_charges`: id, user_fee_id, user_id, location_id, charge_date, amount, status, payment_date, payment_image, notes, bank_id
- RPC: `generate_monthly_fee_charges(p_run_date)` - Genera cargos respetando default_day, usa ON CONFLICT DO NOTHING

**Pendiente en esta Feature:**
1. ⏳ **Botón "Asignar"** - Modal para asignar residentes a un fee
2. ⏳ **Remover asignación** - Funcionalidad del botón eliminar en cada asignación
3. ⏳ **Botón "Borrar"** - Eliminar cargos pendientes seleccionados (checkbox multi-select)
4. ⏳ **Botón "Generar"** - Llamar RPC `generate_monthly_fee_charges` para mes seleccionado
5. ⏳ **Revisar/ajustar RPC** - Es probable que necesite cambios según lógica de negocio
6. ⏳ **Refinar RLS** - Cambiar de permisivo a organization-scoped: `organization_id IN (SELECT organization_id FROM user_profiles WHERE user_id = auth.uid())`
7. ⏳ **Remover debug prints** - Limpiar console.log de producción

---

### Gestión de Tokens de Acceso (`token_form_page.dart`)

- **Nuevo Tipo de Token "Airbnb":**
  - Se implementó un nuevo tipo de token llamado "Airbnb".
  - Se reutilizó la UI del token "Recurrente" para "Airbnb", aplicando el principio DRY (Don't Repeat Yourself) al combinar la lógica con `if (_tokenType == 'Recurrente' || _tokenType == 'Airbnb')`.
  - Se ajustó la lógica para que al seleccionar "Airbnb", las horas de inicio y fin se establezcan por defecto en 00:00 y 23:59 y los campos queden protegidos contra edición.
  - Se corrigió la función de guardado (`saveToken`) para que los tokens "Airbnb" se marquen correctamente como recurrentes (`p_is_recurring = true`), asegurando su validez por múltiples días.
- **Reorganización de la Interfaz:**
  - Se rediseñó la sección de selección de tipo de token, organizando los botones en dos filas para una mejor distribución visual.
  - Se añadió un nuevo botón deshabilitado para "Actividades Comunitarias" como preparación para futuras funcionalidades.
- **Fix Timezone Dinámico (18 Nov 2025):**
  - **Eliminado cálculo de fechas en el frontend** que usaba `AppState.organizationTimeZone` hardcodeado.
  - **Removido parámetro `p_expires_at`** que se calculaba localmente con zona horaria potencialmente incorrecta.
  - **El backend ahora calcula automáticamente** el timezone correcto usando `get_organization_timezone(p_organization_id)` que navega la jerarquía de locations.
  - **Cálculo de fechas delegado al RPC `create_token_1a1`** que usa el timezone correcto de la organización.
  - Eliminada dependencia de `package:timezone/timezone.dart` en este screen.
  - Esto garantiza que los tokens se crean con horarios correctos sin importar el país/timezone de la organización.


### Internacionalización (i18n) y Localización (l10n)

- **Infraestructura:**
  - Implementado `I18nProvider` para gestión dinámica de idiomas y carga de traducciones desde archivos JSON.
  - Implementado selector de idioma en el menú principal (`menu_page.dart`).
  - Añadido soporte para Alemán (`de.json`) como "prueba de fuego" para detectar textos no traducidos.
  - Añadidas las claves de traducción para "Airbnb" y "Actividades Comunitarias" en todos los idiomas.

- **Pantallas Refactorizadas (100% Multilingües):**
  - `login_screen.dart`: Incluyendo notificaciones de error/éxito.
  - `menu_page.dart`: Incluyendo menú emergente, etiquetas de funcionalidades dinámicas desde la BD y textos de funcionalidades bloqueadas.
  - `token_form_page.dart`: Incluyendo categorías de servicios y estados de tokens.
  - `profile_screen.dart`: Incluyendo pestañas, campos de formulario y estados.
  - `incident_form_page.dart`: Incluyendo diálogos y mensajes.
  - `fee_payment_report_page.dart`: Incluyendo diálogos y mensajes.
  - `amenity_reservation_page.dart`: Incluyendo diálogos y mensajes.

- **Formatos Localizados:**
  - Implementado formato localizado para **fechas** (`DateFormat.yMd(locale)`) en las pantallas refactorizadas.
  - Implementado formato localizado para **monedas** (`NumberFormat.simpleCurrency`) en las pantallas de Perfil, Amenidades y Reporte de Pagos.

### Sistema de Notificaciones

- **Unificación:** Migradas todas las notificaciones de `ScaffoldMessenger` a nuestro `NotificationService` centralizado en las pantallas trabajadas, garantizando un estilo consistente.

### Corrección de Bugs
- **Error de Doble Clic:** Solucionado error en `token_form_page.dart` que causaba un crash al hacer doble clic en campos de hora de solo lectura, implementando `enableInteractiveSelection: false`.
- **Carga de Imágenes:** Solucionado bug crítico en `fee_payment_report_page.dart` (y preventivamente en otras pantallas) relacionado con la selección de imágenes.
- **Actualización de UI en Diálogos:** Resuelto problema de actualización de estado en diálogos complejos (`ReportPaymentDialog`) mediante una refactorización de la arquitectura del widget.
- **Compilación en iOS:** Solucionado error `Unable to find a destination` ajustando el `IPHONEOS_DEPLOYMENT_TARGET` a `13.0` en el `Podfile` para garantizar la compatibilidad con el entorno de Xcode.

---

## 🧠 Lecciones Aprendidas Clave

1.  **`FilePicker` y Carga de Datos en Memoria:**
    - **Lección:** Al usar `FilePicker.platform.pickFiles()`, es **mandatorio** especificar `withData: true` si se necesita acceder a los bytes del archivo (`result.files.first.bytes`). Omitir este parámetro causa que `bytes` sea `null`, rompiendo silenciosamente las funcionalidades de carga de imágenes.
    - **Acción Correctiva:** Se ha auditado y corregido el uso de `FilePicker` en toda la aplicación (`fee_payment_report_page.dart`, `profile_photo_picker.dart`, `guest_list_modal.dart`) para incluir este parámetro.

2.  **Gestión de Estado en Diálogos (`AlertDialog`):**
    - **Lección:** Un `AlertDialog` estándar no se reconstruye automáticamente cuando cambia el estado de un widget hijo (`StatefulWidget`) contenido en él. Esto puede causar que la UI (ej. botones de acción) no refleje el estado actual (ej. un archivo ya seleccionado).
    - **Acción Correctiva:** La solución más robusta es refactorizar el diálogo para que el `StatefulWidget` principal devuelva un `Dialog` (o un `AlertDialog` completo) en su método `build`. De esta forma, una sola llamada a `setState()` reconstruye todo el diálogo, asegurando la consistencia de la UI.

---

## ⏳ Tareas Pendientes (FlexiSuite App)

- **Auditoría de Notificaciones:**
  - [ ] Realizar una revisión exhaustiva de todo el código base para encontrar y reemplazar cualquier instancia restante de `ScaffoldMessenger` o textos "hardcodeados" en llamadas a `NotificationService`.

- **Internacionalización de Pantallas Restantes:**
  - [ ] `community_events_page.dart`
  - [ ] `forgot_password_screen.dart`
  - [ ] `signup_screen.dart`
  - [ ] `settings_screen.dart`
  - [ ] Cualquier otro widget o pantalla que aún contenga texto fijo.

---

## 🚀 Próximo Sprint: `flexisuite_portal` (Aplicación Web)

### Objetivo General

Alinear el portal web con los estándares de calidad y funcionalidad de la aplicación móvil, preparando el terreno para la implementación de las funcionalidades complementarias.

### Tareas de Infraestructura

- **Internacionalización (i18n):**
  - [ ] **Implementar `I18nProvider`:** Replicar la misma estructura de `provider` y archivos `JSON` que usamos en la app móvil para la gestión de idiomas.
  - [ ] **Refactorizar Componentes:** Auditar y traducir todos los componentes existentes (login, menús, tablas, formularios) para que consuman las claves de traducción.

- **Localización (l10n):**
  - [ ] **Formatos de Fecha:** Asegurar que todas las fechas mostradas en tablas, reportes y formularios utilicen `DateFormat` con el `locale` correspondiente.
  - [ ] **Formatos de Moneda:** Garantizar que todos los valores monetarios se presenten con el símbolo y formato de moneda adecuados para el `locale` del usuario.

- **Sistema de Notificaciones:**
  - [ ] **Implementar `NotificationService`:** Crear o adaptar un servicio de notificaciones centralizado similar al de la app móvil para estandarizar los mensajes de éxito, error y advertencia.

### Tareas de Funcionalidad (Complemento a la App)

El portal debe servir como el "back-office" para las acciones iniciadas en la app. Se deben preparar las vistas y la lógica para:

- **Validación de Pagos (`fee_payment_report_page`):**
  - [ ] Crear una vista donde los administradores puedan ver los reportes de pago enviados por los residentes.
  - [ ] Implementar la funcionalidad para visualizar la imagen del comprobante.
  - [ ] Añadir botones para "Aprobar" o "Rechazar" el pago, actualizando el estado de la cuota.

- **Gestión de Reservas (`amenity_reservation_page`):**
  - [ ] Desarrollar un calendario o listado para que los administradores puedan ver todas las reservas de amenidades (confirmadas, pendientes).
  - [ ] Implementar la funcionalidad para aprobar, rechazar o cancelar reservas desde el portal.

- **Gestión de Eventos Comunitarios (`community_events_page`):**
  - [ ] Crear una interfaz para que los administradores puedan ver los eventos propuestos por los residentes.
  - [ ] Implementar la lógica para "Aprobar" eventos, haciéndolos visibles para toda la comunidad.
  - [ ] Desarrollar una vista para monitorear los participantes y la logística de los eventos aprobados.

- **Gestión de Incidentes (`incident_form_page`):**
  - [ ] Crear el dashboard de administración de tickets donde se puedan ver, asignar y cambiar el estado de los incidentes reportados por los residentes.
