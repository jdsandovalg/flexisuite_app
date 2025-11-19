-- Nueva versión de la función para usar location_id en users_organizations_rel
CREATE OR REPLACE FUNCTION public.approve_user_for_organization(
  p_user_id uuid, 
  p_admin_org_id uuid, 
  p_location_id uuid, 
  p_codigo_lega text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Insertar o actualizar la relación con el rol 'resident', location_id y codigo_lega.
    INSERT INTO users_organizations_rel (user_id, organization_id, role, location_id, codigo_lega)
    VALUES (p_user_id, p_admin_org_id, 'resident', p_location_id, p_codigo_lega)
    ON CONFLICT (user_id, organization_id) DO UPDATE 
    SET location_id = EXCLUDED.location_id,
        codigo_lega = EXCLUDED.codigo_lega;

    RETURN jsonb_build_object('success', true, 'message', 'Usuario aprobado y asociado exitosamente.');
END;
$$;
