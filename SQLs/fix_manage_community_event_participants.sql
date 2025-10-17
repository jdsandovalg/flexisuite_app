-- SOLUCIÓN: Cambiar RETURNS SETOF record por RETURNS TABLE(...) especificando las columnas

CREATE OR REPLACE FUNCTION public.manage_community_event_participants(
    par_action text, 
    p_event_uuid uuid,
    par_user_ids uuid[] DEFAULT NULL,
    par_invited_by uuid DEFAULT NULL, 
    par_notes text DEFAULT NULL, 
    par_organization_id_override uuid DEFAULT NULL,
    par_user_id uuid DEFAULT NULL
)
RETURNS TABLE (
    participant_id uuid,
    event_id uuid,
    user_id uuid,
    user_name text,
    photo_url text,
    status varchar,
    assigned_at timestamp
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_organization_id UUID;
    v_user_id UUID;
BEGIN
    -- ========= ACCIÓN: AÑADIR UN ÚNICO PARTICIPANTE =========
    IF par_action = 'add' THEN
        -- Si se proporciona un array de user_ids, iteramos sobre ellos
        IF par_user_ids IS NOT NULL THEN
            FOREACH v_user_id IN ARRAY par_user_ids
            LOOP
                INSERT INTO public.community_event_participants (event_id, user_id, invited_by, status, notes)
                VALUES (p_event_uuid, v_user_id, par_invited_by, 'pending', par_notes)
                ON CONFLICT (event_id, user_id) DO NOTHING;
            END LOOP;
        -- Si se proporciona un user_id único, lo insertamos
        ELSIF par_user_id IS NOT NULL THEN
            INSERT INTO public.community_event_participants (event_id, user_id, invited_by, status, notes)
            VALUES (p_event_uuid, par_user_id, par_invited_by, 'pending', par_notes)
            ON CONFLICT (event_id, user_id) DO NOTHING;
        END IF;
        RETURN;

    -- ========= ACCIÓN: LISTAR PARTICIPANTES DE UN EVENTO =========
    ELSIF par_action = 'list_participants' THEN
        RETURN QUERY
        SELECT
            cep.participant_id,
            cep.event_id,
            cep.user_id,
            (u.first_name || ' ' || u.last_name)::TEXT AS user_name,
            u.photo_url::TEXT,
            cep.status,
            cep.assigned_at
        FROM public.community_event_participants cep
        JOIN public.users u ON cep.user_id = u.id
        WHERE cep.event_id = p_event_uuid;

    -- ========= ACCIÓN: LISTAR USUARIOS "INVITABLES" =========
    ELSIF par_action = 'list_invitees' THEN
        IF par_organization_id_override IS NOT NULL THEN
            v_organization_id := par_organization_id_override;
        ELSE
            SELECT organization_id INTO v_organization_id 
            FROM public.community_events 
            WHERE event_id = p_event_uuid;
        END IF;

        RETURN QUERY
        SELECT
            NULL::uuid AS participant_id,
            NULL::uuid AS event_id,
            u.id AS user_id,
            (u.first_name || ' ' || u.last_name)::TEXT AS user_name,
            u.photo_url::TEXT AS photo_url,
            'not_invited'::VARCHAR AS status,
            NULL::TIMESTAMP AS assigned_at
        FROM public.users u
        JOIN public.users_organizations_rel uor ON u.id = uor.user_id
        WHERE u.is_private = FALSE
          AND uor.organization_id = v_organization_id
          AND NOT EXISTS (
              SELECT 1 FROM public.community_event_participants cep
              WHERE cep.event_id = p_event_uuid AND cep.user_id = u.id
          );
    END IF;
END;
$function$;

-- EXPLICACIÓN DEL CAMBIO:
-- 1. Cambié "RETURNS SETOF record" por "RETURNS TABLE (...)" con las columnas específicas
-- 2. Agregué soporte para par_user_ids (array) en la acción 'add' para invitar múltiples usuarios
-- 3. Ahora PostgreSQL sabe exactamente qué columnas retorna cada consulta
-- 4. PostgREST/Supabase puede inferir correctamente la estructura sin necesitar "materialize mode"
