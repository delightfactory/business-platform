-- History and review lists carry request summaries. Daily policy evidence is
-- fetched only by scoped detail reads, so a 732-date request does not multiply
-- list hydration or response size by every date in the page.
CREATE FUNCTION leave.request_summary(p_tenant uuid,p_request uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT pg_catalog.jsonb_build_object('id',r.id,'employee_id',r.employee_id,
   'employee_code',e.employee_code,'employee_name',e.full_name,'employment_id',r.employment_id,
   'employer_entity_id',r.employer_entity_id,'leave_type_id',r.leave_type_id,'leave_type_name',t.name,
   'start_date',r.start_date,'end_date',r.end_date,'total_units',p.total_units,
   'is_half_day',r.is_half_day,'state',r.state,'version',r.version,
   'preview_version',p.preview_version,'request_source',r.request_source,'reason',r.reason,
   'owner_queue',r.owner_queue,'submitted_at',r.submitted_at,'created_at',r.created_at)
 FROM leave.requests r
 JOIN people.employees e ON e.tenant_id=r.tenant_id AND e.id=r.employee_id
 JOIN leave.types t ON t.tenant_id=r.tenant_id AND t.id=r.leave_type_id
 JOIN leave.request_previews p ON p.tenant_id=r.tenant_id AND p.request_id=r.id
   AND p.preview_version=r.current_preview_version
 WHERE r.tenant_id=p_tenant AND r.id=p_request
$f$;
REVOKE ALL ON FUNCTION leave.request_summary(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

DO $f$
DECLARE signature text; definition text;
 needle text:='leave.request_json(p_tenant,id)';
BEGIN
 FOREACH signature IN ARRAY ARRAY[
   'public.leave_my_requests(uuid,integer,integer)',
   'public.leave_hr_queue(uuid,integer,integer)'
 ] LOOP
   definition:=pg_catalog.pg_get_functiondef(signature::regprocedure);
   IF (pg_catalog.length(definition)-pg_catalog.length(pg_catalog.replace(definition,needle,'')))
       <>pg_catalog.length(needle) THEN
     RAISE EXCEPTION 'unexpected_leave_request_list_definition: %',signature;
   END IF;
   EXECUTE pg_catalog.replace(definition,needle,'leave.request_summary(p_tenant,id)');
 END LOOP;
END $f$;
