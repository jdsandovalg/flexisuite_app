-- SOLUCIÓN FINAL: Resolver ambigüedad y agregar soporte para múltiples invitados

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
    out_participant_id uuid,
    out_event_id uuid,
    out_user_id uuid,
    out_user_name text,
    out_photo_url text,
    out_status varchar,
    out_assigned_at timestamp
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_organization_id UUID;
    v_user_id UUID;
BEGIN
    -- ========= ACCIÓN: AÑADIR PARTICIPANTE(S) =========
    IF par_action = 'add' THEN
        -- Si se proporciona un array de user_ids, iteramos sobre ellos
        IF par_user_ids IS NOT NULL AND array_length(par_user_ids, 1) > 0 THEN
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
            (u.first_name || ' ' || u.last_name)::TEXT,
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
            SELECT ce.organization_id INTO v_organization_id 
            FROM public.community_events ce
            WHERE ce.event_id = p_event_uuid;
        END IF;

        RETURN QUERY
        SELECT
            NULL::uuid,
            NULL::uuid,
            u.id,
            (u.first_name || ' ' || u.last_name)::TEXT,
            u.photo_url::TEXT,
            'not_invited'::VARCHAR,
            NULL::TIMESTAMP
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

-- EXPLICACIÓN DE LA SOLUCIÓN:
-- 1. CAMBIO CLAVE: Renombré las columnas del RETURNS TABLE con prefijo "out_"
--    (out_participant_id, out_event_id, out_user_id, etc.)
--    Esto elimina la ambigüedad con las columnas de las tablas
-- 2. ON CONFLICT ahora funciona correctamente sin calificadores
-- 3. Soporte completo para par_user_ids (array de múltiples invitados)
-- 4. La función INSERT entiende que "event_id" y "user_id" se refieren a las columnas de la tabla
