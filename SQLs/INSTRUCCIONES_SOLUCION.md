# Solución al Error: "materialize mode required"

## Problema Identificado

El error ocurre porque la función `manage_community_event_participants` retorna `SETOF record`, que es un tipo genérico sin estructura definida. PostgreSQL y PostgREST no pueden inferir automáticamente las columnas que devuelve, causando el error "materialize mode required".

## Solución

### 1. Aplicar el Script de Corrección en la Base de Datos

**Opción A: Usando el Editor SQL de Supabase**
1. Accede a tu proyecto en Supabase Dashboard
2. Ve a la sección "SQL Editor"
3. Abre el archivo `fix_manage_community_event_participants.sql` que se generó
4. Copia todo el contenido del archivo
5. Pégalo en el editor SQL de Supabase
6. Haz clic en "Run" para ejecutar el script

**Opción B: Usando psql desde la terminal**
```bash
# Si tienes acceso directo a la base de datos
psql -h your-db-host -U postgres -d your-database -f fix_manage_community_event_participants.sql
```

### 2. Cambios Principales de la Función

#### Antes:
```sql
RETURNS SETOF record
```

#### Después:
```sql
RETURNS TABLE (
    participant_id uuid,
    event_id uuid,
    user_id uuid,
    user_name text,
    photo_url text,
    status varchar,
    assigned_at timestamp
)
```

### 3. Mejoras Adicionales Implementadas

La nueva función también incluye:

1. **Soporte para múltiples invitados**: Ahora puedes pasar un array de `user_ids` para invitar a múltiples usuarios de una sola vez
2. **Tipo de columnas explícito**: Todas las columnas tienen tipos claramente definidos
3. **Compatibilidad con PostgREST**: Ya no se requiere "materialize mode"

### 4. Verificación del Código Dart

El código Dart en `community_events_page.dart` **ya es compatible** con la nueva función. No requiere cambios porque:

- En `_fetchInvitees()` (línea ~112): Ya llama correctamente a `list_invitees`
- En `_sendInvitationsAndFinish()` (línea ~268): Ya pasa `par_user_ids` como array

### 5. Probar la Solución

Después de aplicar el script:

1. Reinicia tu aplicación Flutter
2. Navega a la página de "Eventos Comunitarios"
3. Intenta crear un nuevo evento
4. Verifica que el paso 3 (Invitar Colaboradores) carga correctamente la lista de usuarios

### 6. Verificar en Logs

Si tienes el servicio de logs activo, deberías ver:
```
Llamando a manage_community_event_participants con params: {...}
Respuesta de list_invitees: [lista de usuarios]
```

Sin el error anterior de PostgrestException.

## Resumen de la Solución

✅ **Cambio principal**: `RETURNS SETOF record` → `RETURNS TABLE (...)`
✅ **Beneficio**: PostgreSQL y PostgREST pueden inferir la estructura correctamente
✅ **Sin cambios necesarios**: El código Dart ya es compatible
✅ **Mejora adicional**: Soporte para invitaciones múltiples

## Comandos Útiles para Verificar

```sql
-- Ver la definición actual de la función
\df+ manage_community_event_participants

-- Probar la función directamente
SELECT * FROM manage_community_event_participants(
    'list_invitees',
    '00000000-0000-0000-0000-000000000000',
    NULL,
    NULL,
    NULL,
    'tu-organization-id-aqui'::uuid,
    NULL
);
