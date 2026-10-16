-- Existing employees need the same payroll-inclusion choice available at onboarding.
CREATE TABLE people.payroll_inclusion_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id uuid NOT NULL,
 employment_id uuid NOT NULL,
 actor_user_id uuid NOT NULL REFERENCES auth.users(id),
 attempt uuid NOT NULL,
 intent jsonb NOT NULL,
 previous_included boolean NOT NULL,
 included boolean NOT NULL,
 result jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
 FOREIGN KEY(tenant_id,employment_id) REFERENCES people.employments(tenant_id,id),
 UNIQUE(actor_user_id,attempt)
);
CREATE INDEX payroll_inclusion_employment_idx ON people.payroll_inclusion_events(tenant_id,employment_id,id DESC);
ALTER TABLE people.payroll_inclusion_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON people.payroll_inclusion_events FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE people.payroll_inclusion_events_id_seq FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER payroll_inclusion_events_append_only BEFORE UPDATE OR DELETE ON people.payroll_inclusion_events
 FOR EACH ROW EXECUTE FUNCTION people.prevent_audit_mutation();

CREATE FUNCTION public.people_payroll_inclusion(p_tenant_id uuid,p_employment_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); employment people.employments; last_event bigint; frozen boolean;
BEGIN
 IF actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,actor,'people.view') THEN
  RAISE EXCEPTION 'people_payroll_inclusion_forbidden' USING ERRCODE='42501';END IF;
 SELECT * INTO employment FROM people.employments WHERE tenant_id=p_tenant_id AND id=p_employment_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'people_employment_not_found' USING ERRCODE='P0002';END IF;
 SELECT max(id) INTO last_event FROM people.payroll_inclusion_events WHERE tenant_id=p_tenant_id AND employment_id=p_employment_id;
 SELECT EXISTS(SELECT 1 FROM payroll.final_contexts f JOIN payroll.periods p ON p.tenant_id=f.tenant_id AND p.id=f.period_id
  WHERE f.tenant_id=p_tenant_id AND f.employer_id=employment.employer_entity_id AND employment.start_date<=p.ends_on
   AND (employment.end_date IS NULL OR employment.end_date>=p.starts_on)) INTO frozen;
 RETURN jsonb_build_object('included',employment.payroll_eligible,'stamp',md5(to_jsonb(employment)::text||coalesce(last_event::text,'')),
  'locked',frozen,'can_manage',employment.employment_status='active' AND NOT frozen
   AND platform_private.has_people_permission(p_tenant_id,actor,'people.manage')
   AND platform_private.has_people_permission(p_tenant_id,actor,'employment.manage'));
END $f$;
REVOKE ALL ON FUNCTION public.people_payroll_inclusion(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_payroll_inclusion(uuid,uuid) TO authenticated;

CREATE FUNCTION public.set_people_payroll_inclusion(p_tenant_id uuid,p_employment_id uuid,p_expected_stamp text,p_included boolean,p_attempt uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); employment people.employments; previous boolean; command_intent jsonb; receipt people.payroll_inclusion_events; snapshot jsonb; event_id bigint;
BEGIN
 IF actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,actor,'people.manage')
  OR NOT platform_private.has_people_permission(p_tenant_id,actor,'employment.manage') THEN
  RAISE EXCEPTION 'people_payroll_inclusion_forbidden' USING ERRCODE='42501';END IF;
 IF p_tenant_id IS NULL OR p_employment_id IS NULL OR p_included IS NULL OR p_attempt IS NULL
  OR p_expected_stamp IS NULL OR p_expected_stamp !~ '^[a-f0-9]{32}$' THEN
  RAISE EXCEPTION 'people_payroll_inclusion_invalid' USING ERRCODE='22023';END IF;
 -- Match the source/finalization lock ordering, including currently excluded employment.
 PERFORM payroll.lock_source_scope(p_tenant_id);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant_id::text,90427));
 PERFORM 1 FROM auth.users WHERE id=actor FOR SHARE;
 PERFORM 1 FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant_id AND user_id=actor FOR SHARE;
 IF NOT platform_private.has_people_permission(p_tenant_id,actor,'people.manage')
  OR NOT platform_private.has_people_permission(p_tenant_id,actor,'employment.manage') THEN
  RAISE EXCEPTION 'people_payroll_inclusion_forbidden' USING ERRCODE='42501';END IF;
 SELECT * INTO employment FROM people.employments WHERE tenant_id=p_tenant_id AND id=p_employment_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'people_employment_not_found' USING ERRCODE='P0002';END IF;
 PERFORM 1 FROM people.employees WHERE tenant_id=p_tenant_id AND id=employment.employee_id FOR UPDATE;
 SELECT * INTO employment FROM people.employments WHERE tenant_id=p_tenant_id AND id=p_employment_id FOR UPDATE;
 command_intent:=jsonb_build_object('tenant',p_tenant_id,'employment',p_employment_id,'stamp',p_expected_stamp,'included',p_included);
 SELECT * INTO receipt FROM people.payroll_inclusion_events WHERE actor_user_id=actor AND attempt=p_attempt;
 IF FOUND THEN
  IF receipt.intent IS DISTINCT FROM command_intent THEN RAISE EXCEPTION 'people_payroll_inclusion_attempt_conflict' USING ERRCODE='PT409';END IF;
  RETURN receipt.result;
 END IF;
 snapshot:=public.people_payroll_inclusion(p_tenant_id,p_employment_id);
 IF snapshot->>'stamp'<>p_expected_stamp THEN RAISE EXCEPTION 'people_payroll_inclusion_stale' USING ERRCODE='PT409';END IF;
 IF (snapshot->>'locked')::boolean THEN RAISE EXCEPTION 'payroll_people_correction_required' USING ERRCODE='23514';END IF;
 IF employment.employment_status<>'active' THEN RAISE EXCEPTION 'people_employment_not_active' USING ERRCODE='23514';END IF;
 previous:=employment.payroll_eligible;
 UPDATE people.employments SET payroll_eligible=p_included WHERE tenant_id=p_tenant_id AND id=p_employment_id;
 -- Source-history/finalized-scope triggers remain enabled on this real update.
 SELECT * INTO employment FROM people.employments WHERE tenant_id=p_tenant_id AND id=p_employment_id;
 event_id:=nextval('people.payroll_inclusion_events_id_seq'::regclass);
 snapshot:=jsonb_set(jsonb_set(snapshot,'{included}',to_jsonb(p_included)),'{stamp}',to_jsonb(md5(to_jsonb(employment)::text||event_id::text)));
 INSERT INTO people.payroll_inclusion_events(id,tenant_id,employment_id,actor_user_id,attempt,intent,previous_included,included,result) OVERRIDING SYSTEM VALUE
 VALUES(event_id,p_tenant_id,p_employment_id,actor,p_attempt,command_intent,previous,p_included,snapshot);
 RETURN snapshot;
END $f$;
REVOKE ALL ON FUNCTION public.set_people_payroll_inclusion(uuid,uuid,text,boolean,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.set_people_payroll_inclusion(uuid,uuid,text,boolean,uuid) TO authenticated;
