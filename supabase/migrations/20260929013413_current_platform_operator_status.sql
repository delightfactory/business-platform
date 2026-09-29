CREATE FUNCTION public.current_platform_operator_status()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT CASE
    WHEN auth_user.id IS NULL THEN 'revoked'
    WHEN grant_row.user_id IS NULL THEN 'not_operator'
    WHEN grant_row.is_active
      AND auth_user.deleted_at IS NULL
      AND auth_user.email_confirmed_at IS NOT NULL
      AND (auth_user.banned_until IS NULL OR auth_user.banned_until <= pg_catalog.now())
      THEN 'active'
    ELSE 'revoked'
  END
  FROM (SELECT auth.uid() AS user_id) AS caller
  LEFT JOIN auth.users AS auth_user ON auth_user.id = caller.user_id
  LEFT JOIN platform_private.platform_operator_grants AS grant_row ON grant_row.user_id = caller.user_id;
$function$;

REVOKE ALL ON FUNCTION public.current_platform_operator_status() FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.current_platform_operator_status() TO authenticated;
COMMENT ON FUNCTION public.current_platform_operator_status() IS
  'Returns only the current authenticated caller current Platform Operator status.';
