# Solución Completa al Error: "materialize mode required" y "column reference is ambiguous"

## Resumen de los Problemas

1. **Error inicial**: "materialize mode required" - La función retornaba `SETOF record` sin especificar la estructura
2. **Error secundario**: "column reference 'event_id' is ambiguous" - Conflicto de nombres entre columnas de RETURNS TABLE y columnas de tablas

## Solución Implementada

### 1. Aplicar el Script SQL en Supabase

**IMPORTANTE**: Usa el archivo `fix_manage_community_event_participants_final.sql`

**Pasos:**
1. Accede a tu proyecto en Supabase Dashboard
2. Ve a "SQL Editor"
3. Copia el contenido completo del archivo `fix_manage_community_event_participants_final.sql`
4. Pégalo en el editor y ejecuta con "Run"

### 2. Cambios Clave en la Función SQL

#### Cambio Principal: Nombres de Columnas con Prefijo
```sql
-- ANTES (causaba ambigüedad):
RETURNS TABLE (
    participant_id uuid,
    event_id uuid,
    user_id uuid,
    ...
)

-- DESPUÉS (sin ambigüedad):
RETURNS TABLE (
    out_participant_id uuid,
    out_event_id uuid,
    out_user_id uuid,
    out_user_name text,
    out_photo_url text,
    out_status varchar,
    out_assigned_at timestamp
)
```

#### Beneficios:
- ✅ Elimina conflicto de nombres con columnas de tablas
- ✅ PostgreSQL puede identificar claramente las columnas de retorno
- ✅ ON CONFLICT funciona correctamente sin calificadores
- ✅ Soporte para múltiples invitados simultáneos (par_user_ids)

### 3. Cambios en el Código Dart

Los cambios en `community_events_page.dart` ya han sido aplicados:

#### Cambios Realizados:
```dart
// ANTES:
i['user_id']          → DESPUÉS: i['out_user_id']
i['user_name']        → DESPUÉS: i['out_user_name']
invitee['user_id']    → DESPUÉS: invitee['out_user_id']
invitee['user_name']  → DESPUÉS: invitee['out_user_name']
```

### 4. Estructura de la Función Final

La función ahora soporta 3 acciones:

#### a) `add` - Añadir Participantes
```dart
// Ejemplo desde Dart:
await Supabase.instance.client.rpc(
  'manage_community_event_participants',
  params: {
    'par_action': 'add',
    'p_event_uuid': eventId,
    'par_user_ids': ['uuid1', 'uuid2', 'uuid3'], // Array de IDs
    'par_invited_by': currentUserId,
    'par_notes': 'Mensaje de invitación',
  },
);
```

#### b) `list_participants` - Listar Participantes de un Evento
```dart
await Supabase.instance.client.rpc(
  'manage_community_event_participants',
  params: {
    'par_action': 'list_participants',
    'p_event_uuid': eventId,
  },
);
```

#### c) `list_invitees` - Listar Usuarios Invitables
```dart
await Supabase.instance.client.rpc(
  'manage_community_event_participants',
  params: {
    'par_action': 'list_invitees',
    'p_event_uuid': '00000000-0000-0000-0000-000000000000',
    'par_organization_id_override': organizationId,
  },
);
```

### 5. Estructura de Respuesta

Todas las acciones que retornan datos usarán estos nombres de columna:

```json
[
  {
    "out_participant_id": "uuid o null",
    "out_event_id": "uuid o null",
    "out_user_id": "uuid del usuario",
    "out_user_name": "Nombre Completo",
    "out_photo_url": "URL de la foto o null",
    "out_status": "pending|confirmed|cancelled|not_invited",
    "out_assigned_at": "timestamp o null"
  }
]
```

### 6. Verificación de la Solución

Después de aplicar los cambios:

1. **Reinicia tu aplicación Flutter**
2. **Prueba el flujo completo:**
   - Navega a "Eventos Comunitarios"
   - Crea un nuevo evento (Paso 1: Fecha y Hora)
   - Completa los detalles (Paso 2: Título, descripción, imagen)
   - Invita colaboradores (Paso 3: Debe cargar la lista sin errores)
   - Finaliza la creación

3. **Verifica en los logs:**
```
Llamando a manage_community_event_participants con params: {...}
Respuesta de list_invitees: [{"out_user_id": "...", "out_user_name": "..."}]
```

### 7. Comandos SQL Útiles para Debugging

```sql
-- Ver la definición actual de la función
\df+ manage_community_event_participants

-- Probar list_invitees directamente
SELECT * FROM manage_community_event_participants(
    'list_invitees',
    '00000000-0000-0000-0000-000000000000',
    NULL,
    NULL,
    NULL,
    'tu-organization-id'::uuid,
    NULL
);

-- Probar add con múltiples usuarios
SELECT * FROM manage_community_event_participants(
    'add',
    'event-uuid-aqui'::uuid,
    ARRAY['user-uuid-1'::uuid, 'user-uuid-2'::uuid],
    'inviter-uuid'::uuid,
    'Mensaje de invitación',
    NULL,
    NULL
);
```

## Resumen de Archivos

- ✅ `fix_manage_community_event_participants_final.sql` - Script SQL a aplicar en Supabase
- ✅ `lib/screens/community_events_page.dart` - Código Dart actualizado con nuevos nombres
- ✅ `SOLUCION_FINAL_COMPLETA.md` - Este documento con instrucciones completas

## Solución Lista

Todo está listo para usarse:
1. Aplica el script SQL en Supabase
2. El código Dart ya está actualizado
3. Reinicia la app y prueba

## Notas Técnicas

- Los nombres con prefijo `out_` evitan conflictos con variables PL/pgSQL y columnas de tablas
- La función maneja correctamente arrays vacíos en `par_user
