-- RLS policies (recommended) - 19 Nov 2025
-- These policies use the project helper `public.current_user_uuid()` present in the DB
-- NOTE: Run these in your Supabase SQL editor as a DBA (they modify RLS policies)

-- 1) Allow SELECT on users_organizations_rel only for users that belong to the same organization
CREATE POLICY org_members_select_users_organizations_rel
  ON public.users_organizations_rel
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.users_organizations_rel uor2
      WHERE uor2.user_id = public.current_user_uuid()
        AND uor2.organization_id = public.users_organizations_rel.organization_id
    )
  );

-- 2) Allow SELECT on user_location_fees only for members of the same organization
CREATE POLICY org_members_select_user_location_fees
  ON public.user_location_fees
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.users_organizations_rel uor
      WHERE uor.user_id = public.current_user_uuid()
        AND uor.organization_id = public.user_location_fees.organization_id
    )
  );

-- 3) Allow INSERT into user_location_fees only when the caller is an admin of the organization
CREATE POLICY org_admins_insert_user_location_fees
  ON public.user_location_fees
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.users_organizations_rel uor
      WHERE uor.user_id = public.current_user_uuid()
        AND uor.organization_id = public.user_location_fees.organization_id
        AND uor.role = 'admin'
    )
  );

-- 4) Allow UPDATE on user_location_fees only for admins of the organization
CREATE POLICY org_admins_update_user_location_fees
  ON public.user_location_fees
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.users_organizations_rel uor
      WHERE uor.user_id = public.current_user_uuid()
        AND uor.organization_id = public.user_location_fees.organization_id
        AND uor.role = 'admin'
    )
  )
  WITH CHECK (true);

-- 5) (Optional) Allow admins to DELETE assignments
CREATE POLICY org_admins_delete_user_location_fees
  ON public.user_location_fees
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM public.users_organizations_rel uor
      WHERE uor.user_id = public.current_user_uuid()
        AND uor.organization_id = public.user_location_fees.organization_id
        AND uor.role = 'admin'
    )
  );

-- IMPORTANT:
-- 1) Do NOT add WITH CHECK to SELECT policies (that causes the "WITH CHECK cannot be applied to SELECT" error).
-- 2) After applying policies, test with an admin user session. If your app does not set a JWT that the DB recognizes,
--    ensure that `current_user_uuid()` returns the expected value in the DB environment (some projects read it from
--    request headers or use a gateway to set the session).

-- If you need a permissive development policy (temporary), use:
-- CREATE POLICY allow_all_select_users_organizations_rel ON public.users_organizations_rel FOR SELECT USING (true);

