# Plan de Trabajo y Tareas Pendientes - FlexiSuite

Este documento sirve como nuestra guía central para el desarrollo, seguimiento de tareas y registro de lecciones aprendidas.

---

## ✅ Avances y Tareas Completadas

### Gestión de Tokens de Acceso (`token_form_page.dart`)

- **Nuevo Tipo de Token "Airbnb":**
  - Se implementó un nuevo tipo de token llamado "Airbnb".
  - Se reutilizó la UI del token "Recurrente" para "Airbnb", aplicando el principio DRY (Don't Repeat Yourself) al combinar la lógica con `if (_tokenType == 'Recurrente' || _tokenType == 'Airbnb')`.
  - Se ajustó la lógica para que al seleccionar "Airbnb", las horas de inicio y fin se establezcan por defecto en 00:00 y 23:59 y los campos queden protegidos contra edición.
  - Se corrigió la función de guardado (`saveToken`) para que los tokens "Airbnb" se marquen correctamente como recurrentes (`p_is_recurring = true`), asegurando su validez por múltiples días.
- **Reorganización de la Interfaz:**
  - Se rediseñó la sección de selección de tipo de token, organizando los botones en dos filas para una mejor distribución visual.
  - Se añadió un nuevo botón deshabilitado para "Actividades Comunitarias" como preparación para futuras funcionalidades.

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
