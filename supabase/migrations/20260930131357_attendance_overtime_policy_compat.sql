CREATE FUNCTION public.save_time_work_policy(
  p_tenant_id uuid,p_template_id uuid,p_code text,p_name text,p_kind text,p_timezone text,p_work_days smallint[],
  p_start time,p_end time,p_next_day boolean,p_break integer,p_required integer,p_earliest time,p_latest time,
  p_before integer,p_after integer
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $f$
  SELECT public.save_time_work_policy(
    p_tenant_id,p_template_id,p_code,p_name,p_kind,p_timezone,p_work_days,p_start,p_end,p_next_day,p_break,p_required,
    p_earliest,p_latest,p_before,p_after,false,30,15
  )
$f$;
REVOKE ALL ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer) TO authenticated;
