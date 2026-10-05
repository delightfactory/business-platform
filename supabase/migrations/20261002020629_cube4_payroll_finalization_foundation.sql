-- Slice 4 private approval/final-output foundations. G6: no public irreversible finalization.
ALTER TABLE payroll.runs DROP CONSTRAINT runs_status_check;
ALTER TABLE payroll.runs ADD CHECK(status IN('draft','review','approved','locked','superseded','cancelled'));
DROP INDEX payroll.payroll_one_active_run;
CREATE UNIQUE INDEX payroll_one_active_run ON payroll.runs(tenant_id,employer_id,period_id) WHERE status IN('draft','review','approved','locked');
CREATE TABLE payroll.approval_events(
 tenant_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),employer_id uuid NOT NULL,run_id uuid NOT NULL,candidate_id uuid NOT NULL,
 operation text NOT NULL CHECK(operation IN('approve','release')),run_revision integer NOT NULL,actor_id uuid NOT NULL REFERENCES auth.users(id),reason text NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,run_id,id),
 FOREIGN KEY(tenant_id,employer_id,run_id) REFERENCES payroll.runs(tenant_id,employer_id,id),FOREIGN KEY(tenant_id,candidate_id) REFERENCES payroll.candidates(tenant_id,id));
ALTER TABLE payroll.runs ADD COLUMN approval_id uuid;
ALTER TABLE payroll.runs ADD FOREIGN KEY(tenant_id,id,approval_id) REFERENCES payroll.approval_events(tenant_id,run_id,id);
CREATE TABLE payroll.final_contexts(
 tenant_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),employer_id uuid NOT NULL,period_id uuid NOT NULL,run_id uuid NOT NULL,candidate_id uuid NOT NULL,approval_id uuid NOT NULL,
 legal_employer jsonb NOT NULL,period_snapshot jsonb NOT NULL,manifest jsonb NOT NULL,result jsonb NOT NULL,engine_version text NOT NULL,
 finalized_by uuid NOT NULL REFERENCES auth.users(id),finalized_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,run_id),UNIQUE(tenant_id,employer_id,id),
 FOREIGN KEY(tenant_id,employer_id,run_id) REFERENCES payroll.runs(tenant_id,employer_id,id),FOREIGN KEY(tenant_id,candidate_id) REFERENCES payroll.candidates(tenant_id,id),FOREIGN KEY(tenant_id,run_id,approval_id) REFERENCES payroll.approval_events(tenant_id,run_id,id),FOREIGN KEY(tenant_id,period_id) REFERENCES payroll.periods(tenant_id,id));
CREATE TABLE payroll.final_employees(
 tenant_id uuid NOT NULL,employer_id uuid NOT NULL,output_id uuid NOT NULL,employment_id uuid NOT NULL,employee_snapshot jsonb NOT NULL,
 explanation jsonb NOT NULL,statutory_context jsonb NOT NULL,net numeric(18,2) NOT NULL CHECK(net>=0),
 PRIMARY KEY(tenant_id,output_id,employment_id),FOREIGN KEY(tenant_id,employer_id,output_id) REFERENCES payroll.final_contexts(tenant_id,employer_id,id),FOREIGN KEY(tenant_id,employment_id) REFERENCES people.employments(tenant_id,id));
CREATE TABLE payroll.output_successions(
 tenant_id uuid NOT NULL,original_output uuid NOT NULL,replacement_output uuid NOT NULL,actor_id uuid NOT NULL REFERENCES auth.users(id),reason text NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,original_output),FOREIGN KEY(tenant_id,original_output) REFERENCES payroll.final_contexts(tenant_id,id),FOREIGN KEY(tenant_id,replacement_output) REFERENCES payroll.final_contexts(tenant_id,id),CHECK(original_output<>replacement_output));
-- No succession command exists until payment-aware correction closure.
DO $f$ DECLARE tab text;BEGIN
 FOREACH tab IN ARRAY ARRAY['approval_events','final_contexts','final_employees','output_successions'] LOOP
  EXECUTE format('ALTER TABLE payroll.%I ENABLE ROW LEVEL SECURITY',tab);
  EXECUTE format('CREATE TRIGGER immutable BEFORE UPDATE OR DELETE ON payroll.%I FOR EACH ROW EXECUTE FUNCTION payroll.immutable()',tab);
  EXECUTE format('REVOKE ALL ON payroll.%I FROM PUBLIC,anon,authenticated,service_role',tab);
 END LOOP;
END $f$;
CREATE FUNCTION payroll.guard_run_lifecycle() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 IF OLD.status IN('locked','superseded','cancelled') OR(NEW.tenant_id,NEW.employer_id,NEW.period_id,NEW.id,NEW.created_by,NEW.created_at) IS DISTINCT FROM(OLD.tenant_id,OLD.employer_id,OLD.period_id,OLD.id,OLD.created_by,OLD.created_at) THEN RAISE EXCEPTION 'payroll_immutable' USING ERRCODE='55000';END IF;
 IF NEW.revision<>OLD.revision+1 OR OLD.status='approved' AND NEW.status NOT IN('review','locked') OR NEW.status='approved' AND(OLD.status<>'review' OR NEW.candidate_id IS DISTINCT FROM OLD.candidate_id OR NEW.approval_id IS NULL) OR NEW.status='locked' AND(OLD.status<>'approved' OR NEW.candidate_id IS DISTINCT FROM OLD.candidate_id OR NEW.approval_id IS DISTINCT FROM OLD.approval_id) THEN RAISE EXCEPTION 'payroll_run_stale' USING ERRCODE='PT409';END IF;
 RETURN NEW;
END $f$;
CREATE TRIGGER payroll_run_lifecycle BEFORE UPDATE ON payroll.runs FOR EACH ROW EXECUTE FUNCTION payroll.guard_run_lifecycle();
-- Match the existing catalog/import order before E/H. Never acquire Tenant serialization beneath H.
CREATE FUNCTION payroll.lock_source_scope(p_tenant uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM set_config('lock_timeout','5s',true);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,0));
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,90427));
END $f$;
DO $f$ DECLARE proc record;definition text;BEGIN
 FOR proc IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='payroll' AND p.proname IN('lock_scope','lock_input_scope','lock_run_scope') LOOP
  definition:=pg_get_functiondef(proc.oid);
  definition:=regexp_replace(definition,'BEGIN',E'BEGIN\n PERFORM payroll.lock_source_scope(p_tenant);');EXECUTE definition;
 END LOOP;
 -- Read compiled definitions: this preserves current People/Time dynamic patches and all business validation/audit.
 FOR proc IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN('create_people_employee','rehire_people_employee','confirm_people_workforce_import','change_people_compensation','cancel_people_compensation_change','schedule_people_work_assignment','correct_initial_people_work_assignment','cancel_people_work_assignment','end_people_employment','assign_people_work_policy') LOOP
  definition:=pg_get_functiondef(proc.oid);
  IF definition NOT LIKE '%p_tenant_id%' THEN RAISE EXCEPTION 'unexpected_people_writer_signature';END IF;
  definition:=regexp_replace(definition,'BEGIN',E'BEGIN\n IF auth.uid() IS NOT NULL THEN PERFORM payroll.lock_source_scope(p_tenant_id);END IF;');EXECUTE definition;
 END LOOP;
 -- Approved/finalized states require explicit release; keep calculation/cancellation semantics unchanged otherwise.
 definition:=pg_get_functiondef('public.payroll_run_command(uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);
 definition:=replace(definition,'run.status=''cancelled''','run.status NOT IN(''draft'',''review'')');
 definition:=replace(definition,'status IN(''draft'',''review'')','status IN(''draft'',''review'',''approved'',''locked'')');EXECUTE definition;
 definition:=pg_get_functiondef('payroll.guard_open_run_calendar()'::regprocedure);
 EXECUTE replace(definition,'status IN(''draft'',''review'')','status IN(''draft'',''review'',''approved'')');
 definition:=pg_get_functiondef('public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid)'::regprocedure);
 IF definition NOT LIKE '%f.tenant_id=p_tenant AND f.employer_id=p_employer%' THEN RAISE EXCEPTION 'unexpected_frozen_input_guard';END IF;
 EXECUTE replace(definition,'f.tenant_id=p_tenant AND f.employer_id=p_employer','f.tenant_id=p_tenant AND(f.employer_id=p_employer OR p_kind=''policy'')');
END $f$;
-- New eligibility within a finalized Employer period is material even if no previous H was consumed.
CREATE FUNCTION payroll.guard_final_employment_scope() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE old_data jsonb;new_data jsonb;f record;old_range daterange;new_range daterange;BEGIN
 old_data:=CASE WHEN TG_OP='INSERT' THEN NULL ELSE to_jsonb(OLD) END;new_data:=CASE WHEN TG_OP='DELETE' THEN NULL ELSE to_jsonb(NEW) END;
 IF old_data IS NOT NULL AND(old_data->>'payroll_eligible')::boolean THEN old_range:=daterange((old_data->>'start_date')::date,(old_data->>'end_date')::date,'[]');END IF;
 IF new_data IS NOT NULL AND(new_data->>'payroll_eligible')::boolean THEN new_range:=daterange((new_data->>'start_date')::date,(new_data->>'end_date')::date,'[]');END IF;
 FOR f IN SELECT c.employer_id,p.starts_on,p.ends_on FROM payroll.final_contexts c JOIN payroll.periods p ON p.tenant_id=c.tenant_id AND p.id=c.period_id WHERE c.tenant_id=COALESCE((new_data->>'tenant_id')::uuid,(old_data->>'tenant_id')::uuid) AND c.employer_id IN((old_data->>'employer_entity_id')::uuid,(new_data->>'employer_entity_id')::uuid) LOOP
  IF COALESCE(CASE WHEN f.employer_id=(old_data->>'employer_entity_id')::uuid THEN old_range*daterange(f.starts_on,f.ends_on,'[]') END,'empty'::daterange) IS DISTINCT FROM COALESCE(CASE WHEN f.employer_id=(new_data->>'employer_entity_id')::uuid THEN new_range*daterange(f.starts_on,f.ends_on,'[]') END,'empty'::daterange) THEN RAISE EXCEPTION 'payroll_people_correction_required' USING ERRCODE='23514';END IF;
 END LOOP;
 IF TG_OP='DELETE' THEN RETURN OLD;ELSE RETURN NEW;END IF;
END $f$;
CREATE TRIGGER payroll_final_employment_scope BEFORE INSERT OR UPDATE OR DELETE ON people.employments FOR EACH ROW EXECUTE FUNCTION payroll.guard_final_employment_scope();
-- Existing H/compensation/assignment history guard retains lawful prospective closures.
CREATE FUNCTION payroll.lock_finalization_sources(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM set_config('lock_timeout','5s',true);
 PERFORM payroll.lock_run_scope(p_tenant,p_employer,p_period);
 PERFORM 1 FROM payroll.calendar_heads WHERE tenant_id=p_tenant AND employer_id=p_employer ORDER BY employer_id FOR UPDATE;
 PERFORM 1 FROM payroll.input_heads WHERE tenant_id=p_tenant AND(employer_id=p_employer OR kind='policy') ORDER BY id FOR UPDATE;
 PERFORM 1 FROM payroll.input_versions v JOIN payroll.input_heads h ON h.tenant_id=v.tenant_id AND h.id=v.head_id WHERE h.tenant_id=p_tenant AND(h.employer_id=p_employer OR h.kind='policy') ORDER BY v.id FOR SHARE OF v;
 LOCK TABLE payroll.statutory_packs IN SHARE MODE;
 -- Enabled source domains remain blocked by qualification; no unsafe W -> Leave lock is introduced.
END $f$;
CREATE FUNCTION payroll.approval_readiness(p_candidate payroll.candidates) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE stale jsonb;blockers integer;BEGIN
 stale:=payroll.stale_reasons(p_candidate.input_manifest,payroll.run_manifest(p_candidate.tenant_id,p_candidate.employer_id,(p_candidate.input_manifest->'period'->>'id')::uuid));
 SELECT count(*) INTO blockers FROM(SELECT i FROM jsonb_array_elements(p_candidate.output->'issues')i UNION SELECT i FROM jsonb_array_elements(p_candidate.output->'employees')e CROSS JOIN LATERAL jsonb_array_elements(e->'issues')i)all_issues WHERE COALESCE((i->>'blocking')::boolean,true);
 RETURN jsonb_build_object('stale_reasons',stale,'blocking_count',blockers,'ready',stale='[]'::jsonb AND blockers=0 AND COALESCE((p_candidate.output->>'financially_qualified')::boolean,false) AND COALESCE((p_candidate.output->>'gross_complete')::boolean,false) AND p_candidate.output->>'net' IS NOT NULL AND(p_candidate.output->>'net')::numeric>=0 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_candidate.output->'employees')e WHERE e->>'net' IS NULL OR(e->>'net')::numeric<0 OR e->'statutory_context'->>'calendar_year' IS NULL OR e->'statutory_context'->>'category' IS NULL OR e->'statutory_context'->>'insured_wage_source' IS NULL OR e->'statutory_context'->>'insured_wage' IS NULL OR jsonb_typeof(e->'statutory_context'->'obligation_months') IS DISTINCT FROM 'array'));

END $f$;
CREATE FUNCTION public.payroll_candidate_approval(p_tenant uuid,p_employer uuid,p_period uuid,p_run uuid,p_candidate uuid,p_expected integer,p_operation text,p_reason text,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;r payroll.runs%ROWTYPE;c payroll.candidates%ROWTYPE;intent jsonb;receipt payroll.command_receipts%ROWTYPE;readiness jsonb;event uuid;result jsonb;BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.approve',true);
 IF p_operation IS NULL OR p_operation NOT IN('approve','release') OR p_expected IS NULL OR p_expected<0 OR p_attempt IS NULL OR p_candidate IS NULL OR length(COALESCE(btrim(p_reason),'')) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 PERFORM payroll.lock_finalization_sources(p_tenant,p_employer,p_period);a:=payroll.authorized(p_tenant,'payroll.approve',true);
 intent:=jsonb_build_object('operation','candidate_'||p_operation,'employer',p_employer,'period',p_period,'run',p_run,'candidate',p_candidate,'expected',p_expected,'reason',btrim(p_reason));
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 SELECT * INTO r FROM payroll.runs WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=p_period AND id=p_run FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF r.revision<>p_expected OR r.candidate_id IS DISTINCT FROM p_candidate OR p_operation='approve' AND r.status<>'review' OR p_operation='release' AND r.status<>'approved' THEN RAISE EXCEPTION 'payroll_run_stale' USING ERRCODE='PT409';END IF;
 SELECT * INTO c FROM payroll.candidates WHERE tenant_id=p_tenant AND employer_id=p_employer AND run_id=p_run AND id=p_candidate;
 readiness:=payroll.approval_readiness(c);
 IF p_operation='approve' AND readiness->'stale_reasons'<>'[]'::jsonb THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409';END IF;
 IF p_operation='approve' AND NOT(readiness->>'ready')::boolean THEN RAISE EXCEPTION 'payroll_approval_blocked' USING ERRCODE='23514';END IF;
 INSERT INTO payroll.approval_events(tenant_id,employer_id,run_id,candidate_id,operation,run_revision,actor_id,reason) VALUES(p_tenant,p_employer,p_run,p_candidate,p_operation,r.revision+1,a,btrim(p_reason)) RETURNING id INTO event;
 UPDATE payroll.runs SET status=CASE WHEN p_operation='approve' THEN 'approved' ELSE 'review' END,revision=revision+1,approval_id=CASE WHEN p_operation='approve' THEN event END WHERE tenant_id=p_tenant AND id=p_run;
 result:=jsonb_build_object('id',p_run,'revision',r.revision+1,'candidate_id',p_candidate,'approval_id',event,'status',CASE WHEN p_operation='approve' THEN 'approved' ELSE 'review' END);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'candidate_'||p_operation,intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);
 PERFORM payroll.authorized(p_tenant,'payroll.approve',true);RETURN result;
END $f$;
-- Deterministic append foundation: private trusted caller only. Synthetic fixtures may exercise this inside ROLLBACK.
-- It is not an exposed legal adapter or a qualification bypass; finalize_run below never reaches it in this release.
CREATE FUNCTION payroll.append_final_output(p_tenant uuid,p_run uuid,p_candidate uuid,p_actor uuid,p_expected integer,p_attempt uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE r payroll.runs%ROWTYPE;c payroll.candidates%ROWTYPE;e jsonb;h jsonb;output uuid;employer jsonb;snapshot jsonb;input record;v payroll.input_versions%ROWTYPE;receipt payroll.command_receipts%ROWTYPE;intent jsonb;BEGIN
 IF p_actor IS DISTINCT FROM payroll.authorized(p_tenant,'payroll.lock',true) OR p_attempt IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM payroll.runs WHERE tenant_id=p_tenant AND id=p_run;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 PERFORM payroll.lock_finalization_sources(p_tenant,r.employer_id,r.period_id);
 PERFORM payroll.authorized(p_tenant,'payroll.lock',true);
 intent:=jsonb_build_object('operation','private_final_append','run',p_run,'candidate',p_candidate,'expected',p_expected);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=p_actor AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN(receipt.result->>'output')::uuid;END IF;
 SELECT * INTO r FROM payroll.runs WHERE tenant_id=p_tenant AND id=p_run FOR UPDATE;
 IF p_expected IS NULL OR r.revision<>p_expected THEN RAISE EXCEPTION 'payroll_run_stale' USING ERRCODE='PT409';END IF;
 SELECT * INTO c FROM payroll.candidates WHERE tenant_id=p_tenant AND run_id=p_run AND id=p_candidate;
 IF r.status<>'approved' OR r.candidate_id IS DISTINCT FROM p_candidate OR r.approval_id IS NULL OR c.id IS NULL OR NOT(payroll.approval_readiness(c)->>'ready')::boolean THEN RAISE EXCEPTION 'payroll_approval_blocked' USING ERRCODE='23514';END IF;
 SELECT jsonb_build_object('display_name',display_name,'legal_name',legal_name) INTO employer FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=r.employer_id;
 IF employer->>'legal_name' IS NULL OR length(btrim(employer->>'legal_name'))=0 THEN RAISE EXCEPTION 'payroll_legal_employer_missing' USING ERRCODE='23514';END IF;
 INSERT INTO payroll.final_contexts(tenant_id,employer_id,period_id,run_id,candidate_id,approval_id,legal_employer,period_snapshot,manifest,result,engine_version,finalized_by) VALUES(p_tenant,r.employer_id,r.period_id,p_run,p_candidate,r.approval_id,employer,c.input_manifest->'period',c.input_manifest,c.output,c.engine_version,p_actor) RETURNING id INTO output;
 FOR e IN SELECT value FROM jsonb_array_elements(c.output->'employees') LOOP
  IF e->>'net' IS NULL OR jsonb_typeof(e->'statutory_context') IS DISTINCT FROM 'object' OR e->'statutory_context'->>'calendar_year' IS NULL OR e->'statutory_context'->>'category' IS NULL OR e->'statutory_context'->>'insured_wage_source' IS NULL OR e->'statutory_context'->>'insured_wage' IS NULL OR jsonb_typeof(e->'statutory_context'->'obligation_months') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'payroll_statutory_unqualified' USING ERRCODE='23514';END IF;
  INSERT INTO payroll.final_employees VALUES(p_tenant,r.employer_id,output,(e->>'employment_id')::uuid,jsonb_build_object('name',e->>'name','code',e->>'code'),payroll.review_employee_detail(e),e->'statutory_context',(e->>'net')::numeric);
  SELECT value->'employment' INTO h FROM jsonb_array_elements(c.input_manifest->'employees') WHERE value->'employment'->>'id'=e->>'employment_id';
  snapshot:=jsonb_build_object('employment',h,'compensation',COALESCE((SELECT jsonb_agg(x ORDER BY x->>'valid_from',x->>'id') FROM jsonb_array_elements(c.input_manifest->'compensation')x WHERE x->>'employment_id'=e->>'employment_id'),'[]'),'assignments',COALESCE((SELECT jsonb_agg(x ORDER BY x->>'valid_from',x->>'id') FROM jsonb_array_elements(c.input_manifest->'assignments')x WHERE x->>'employment_id'=e->>'employment_id'),'[]'));
  PERFORM payroll.register_people_context(p_tenant,r.employer_id,(e->>'employment_id')::uuid,r.period_id,p_run,snapshot);
 END LOOP;
 FOR input IN SELECT DISTINCT(i->'version'->>'id')::uuid AS id FROM jsonb_array_elements(c.input_manifest->'inputs')i LOOP
  INSERT INTO payroll.input_frozen_versions VALUES(p_tenant,p_run,input.id);
 END LOOP;
 -- Approved adjustments are applied exactly once by a new immutable version, never by rewriting approved money.
 FOR v IN SELECT iv.* FROM payroll.input_heads ih JOIN payroll.input_versions iv ON iv.tenant_id=ih.tenant_id AND iv.head_id=ih.id AND iv.revision=ih.revision WHERE ih.tenant_id=p_tenant AND ih.employer_id=r.employer_id AND ih.period_id=r.period_id AND ih.kind='adjustment' AND iv.status='approved' ORDER BY ih.id LOOP
  INSERT INTO payroll.input_versions(tenant_id,employer_id,head_id,revision,data,effective_from,effective_until,status,created_by,approved_by,approved_at) VALUES(v.tenant_id,v.employer_id,v.head_id,v.revision+1,v.data,v.effective_from,v.effective_until,'applied',p_actor,v.approved_by,v.approved_at);
  UPDATE payroll.input_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND id=v.head_id;
 END LOOP;
 UPDATE payroll.runs SET status='locked',revision=revision+1 WHERE tenant_id=p_tenant AND id=p_run;
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,r.employer_id,p_actor,'run_finalized',jsonb_build_object('run',p_run,'candidate',p_candidate,'output',output,'approval',r.approval_id));
 INSERT INTO payroll.command_receipts VALUES(p_tenant,p_actor,p_attempt,intent,jsonb_build_object('output',output,'run',p_run,'status','locked'));
 PERFORM payroll.authorized(p_tenant,'payroll.lock',true);RETURN output;
END $f$;
CREATE FUNCTION payroll.finalize_run(p_tenant uuid,p_employer uuid,p_period uuid,p_run uuid,p_candidate uuid,p_expected integer,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;r payroll.runs%ROWTYPE;c payroll.candidates%ROWTYPE;BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.lock',true);PERFORM payroll.lock_finalization_sources(p_tenant,p_employer,p_period);a:=payroll.authorized(p_tenant,'payroll.lock',true);
 SELECT * INTO r FROM payroll.runs WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=p_period AND id=p_run FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_attempt IS NULL OR r.revision<>p_expected OR r.status<>'approved' OR r.candidate_id IS DISTINCT FROM p_candidate THEN RAISE EXCEPTION 'payroll_run_stale' USING ERRCODE='PT409';END IF;
 SELECT * INTO c FROM payroll.candidates WHERE tenant_id=p_tenant AND run_id=p_run AND id=p_candidate;
 IF NOT(payroll.approval_readiness(c)->>'ready')::boolean THEN RAISE EXCEPTION 'payroll_approval_blocked' USING ERRCODE='23514';END IF;
 -- No runtime flag or grant can open G6. Payment/correction, legal adapters and source contracts must be closed in later migrations.
 RAISE EXCEPTION 'payroll_release_gate' USING ERRCODE='55000';
END $f$;
-- Protected final-only retrieval, never a candidate payslip. Each bounded access is audited.
CREATE FUNCTION public.payroll_final_output(p_tenant uuid,p_employer uuid,p_output uuid,p_employee uuid DEFAULT NULL,p_after uuid DEFAULT NULL,p_limit integer DEFAULT 30,p_export boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;c payroll.final_contexts%ROWTYPE;items jsonb;superseded boolean;BEGIN
 a:=payroll.authorized(p_tenant,CASE WHEN p_export THEN 'payroll.export' ELSE 'payroll.view' END,false);
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 OR p_export IS NULL THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 SELECT * INTO c FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 superseded:=EXISTS(SELECT 1 FROM payroll.output_successions WHERE tenant_id=p_tenant AND original_output=p_output);
 IF superseded AND p_export THEN RAISE EXCEPTION 'payroll_output_superseded' USING ERRCODE='23514';END IF;
 SELECT COALESCE(jsonb_agg(jsonb_build_object('employment_id',employment_id,'employee',employee_snapshot,'explanation',explanation,'net',net::text) ORDER BY employment_id),'[]') INTO items FROM(SELECT * FROM payroll.final_employees WHERE tenant_id=p_tenant AND employer_id=p_employer AND output_id=p_output AND(p_employee IS NULL OR employment_id=p_employee) AND(p_after IS NULL OR employment_id>p_after) ORDER BY employment_id LIMIT p_limit)x;
 IF p_employee IS NOT NULL AND items='[]'::jsonb THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,CASE WHEN p_export THEN 'final_export_access' ELSE 'final_output_access' END,jsonb_build_object('output',p_output,'employee',p_employee,'after',p_after,'count',jsonb_array_length(items),'superseded',superseded));
 PERFORM payroll.authorized(p_tenant,CASE WHEN p_export THEN 'payroll.export' ELSE 'payroll.view' END,false);
 RETURN jsonb_build_object('output_id',p_output,'legal_employer',c.legal_employer,'period',c.period_snapshot-'id'-'tenant_id'-'employer_id'-'calendar_version_id'-'created_by','superseded',superseded,'employees',items);
END $f$;
-- Scope-safe readiness/approval evidence is added to the bounded run workspace.
DO $f$ DECLARE definition text;BEGIN
 definition:=pg_get_functiondef('public.payroll_run_access(uuid)'::regprocedure);
 definition:=replace(definition,'OR platform_private.has_tenant_permission(p_tenant,a,''payroll.review''))','OR platform_private.has_tenant_permission(p_tenant,a,''payroll.review'') OR platform_private.has_tenant_permission(p_tenant,a,''payroll.approve''))');
 definition:=replace(definition,'''can_view'',can_view,','''can_view'',can_view,''can_view_final'',platform_private.has_tenant_permission(p_tenant,a,''payroll.view''),''can_approve'',platform_private.has_tenant_permission(p_tenant,a,''payroll.approve''),');EXECUTE definition;
 definition:=pg_get_functiondef('public.payroll_run_workspace(uuid,uuid,uuid,uuid,integer,uuid,text)'::regprocedure);
 -- Finalized workspace is navigation/history only. Financial data always uses the audited protected accessor.
 IF definition NOT LIKE '%IF run.candidate_id IS NOT NULL THEN%' THEN RAISE EXCEPTION 'unexpected_workspace_candidate_gate';END IF;
 definition:=replace(definition,'IF run.candidate_id IS NOT NULL THEN','IF run.candidate_id IS NOT NULL AND run.status NOT IN(''locked'',''superseded'') THEN');
 definition:=replace(definition,'IF run.status<>''cancelled'' THEN stale','IF run.status IN(''draft'',''review'',''approved'') THEN stale');
 definition:=replace(definition,'''id'',run.id,''revision'',run.revision,','''id'',run.id,''candidate_id'',run.candidate_id,''revision'',run.revision,');
 definition:=replace(definition,'''summary'',summary,','''final_output_id'',(SELECT id FROM payroll.final_contexts WHERE tenant_id=p_tenant AND run_id=run.id),''approval'',CASE WHEN candidate.id IS NOT NULL THEN payroll.approval_readiness(candidate) END,''approval_history'',COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT operation,actor_id,reason,created_at FROM payroll.approval_events WHERE tenant_id=p_tenant AND run_id=run.id ORDER BY created_at DESC LIMIT 24)x),''[]''),''summary'',summary,');EXECUTE definition;
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_candidate_approval(uuid,uuid,uuid,uuid,uuid,integer,text,text,uuid),public.payroll_final_output(uuid,uuid,uuid,uuid,uuid,integer,boolean) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_candidate_approval(uuid,uuid,uuid,uuid,uuid,integer,text,text,uuid),public.payroll_final_output(uuid,uuid,uuid,uuid,uuid,integer,boolean) TO authenticated;
-- Payroll-specific rational fractions preserve exact half-cent ties without epsilon or precision guesses.
CREATE FUNCTION payroll.parts_fraction(p_parts jsonb) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE item jsonb;fraction jsonb;n numeric:=0;d numeric:=1;pn numeric;pd numeric;a numeric;b numeric;g numeric;remainder numeric;BEGIN
 FOR item IN SELECT value FROM jsonb_array_elements(COALESCE(p_parts,'[]')) LOOP
  IF item->>'_numerator' IS NOT NULL THEN pn:=(item->>'_numerator')::numeric;pd:=(item->>'_denominator')::numeric;
  ELSIF item->'detail' IS NOT NULL THEN fraction:=payroll.parts_fraction(item->'detail');pn:=(fraction->>'n')::numeric;pd:=(fraction->>'d')::numeric;
  ELSE pn:=(item->>'raw')::numeric*100;pd:=100;END IF;
  IF pn IS NULL OR pd IS NULL OR pn<>trunc(pn) OR pd<>trunc(pd) OR pd<=0 THEN RAISE EXCEPTION 'payroll_fraction_invalid' USING ERRCODE='22023';END IF;
  -- Reduce the common denominator before addition, then reduce the resulting fraction.
  a:=d;b:=pd;WHILE b<>0 LOOP remainder:=mod(a,b);a:=b;b:=remainder;END LOOP;g:=a;
  n:=n*(pd/g)+pn*(d/g);d:=d*(pd/g);
  a:=abs(n);b:=d;WHILE b<>0 LOOP remainder:=mod(a,b);a:=b;b:=remainder;END LOOP;
  IF a>0 THEN n:=n/a;d:=d/a;END IF;
 END LOOP;
 RETURN jsonb_build_object('n',n::text,'d',d::text);
END $f$;
CREATE FUNCTION payroll.round_fraction(p_fraction jsonb) RETURNS numeric LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE n numeric:=(p_fraction->>'n')::numeric;d numeric:=(p_fraction->>'d')::numeric;cents numeric;remainder numeric;BEGIN
 IF n IS NULL OR d IS NULL OR n<>trunc(n) OR d<>trunc(d) OR d<=0 THEN RAISE EXCEPTION 'payroll_fraction_invalid' USING ERRCODE='22023';END IF;
 cents:=div(abs(n)*100,d);remainder:=mod(abs(n)*100,d);
 IF remainder*2>=d THEN cents:=cents+1;END IF;
 RETURN sign(n)*cents/100;
END $f$;
DO $f$ DECLARE definition text;BEGIN
 definition:=pg_get_functiondef('payroll.build_review(jsonb)'::regprocedure);
 IF definition NOT LIKE '%round(sum((part->>''raw'')::numeric),2)%' THEN RAISE EXCEPTION 'unexpected_review_rounding';END IF;
 definition:=replace(definition,'component_part numeric;','component_part numeric;part_n numeric;part_d numeric;');
 definition:=replace(definition,'''rate'',rate::text,''denominator'',denominator,','''rate'',rate::text,''denominator'',denominator,''_numerator'',(rate*100)::text,''_denominator'',(denominator*100)::text,');
 definition:=replace(definition,'jsonb_build_object(''raw'',(minimum_rate*units/eligible_days)::text)','jsonb_build_object(''raw'',(minimum_rate*units/eligible_days)::text,''_numerator'',(minimum_rate*100*units*100)::text,''_denominator'',(eligible_days*10000)::text)');
 definition:=replace(definition,'round(base_raw,2)','payroll.round_fraction(payroll.parts_fraction(base_parts))');
 definition:=replace(definition,'SELECT(b->>''raw'')::numeric INTO component_part','SELECT(b->>''raw'')::numeric,(b->>''_numerator'')::numeric,(b->>''_denominator'')::numeric INTO component_part,part_n,part_d');
 definition:=replace(definition,'component_part:=component_part*component_value/100;','component_part:=component_part*component_value/100;part_n:=part_n*component_value*100;part_d:=part_d*10000;');
 definition:=replace(definition,'component_part:=component_value::numeric(38,20)/denominator;','component_part:=component_value::numeric(38,20)/denominator;part_n:=component_value*100;part_d:=denominator*100;');
 definition:=replace(definition,'''raw'',component_part::text,''date'',d,','''raw'',component_part::text,''_numerator'',part_n::text,''_denominator'',part_d::text,''date'',d,');
 definition:=replace(definition,'round(sum((part->>''raw'')::numeric),2)','payroll.round_fraction(payroll.parts_fraction(jsonb_agg(part)))');
 definition:=replace(definition,'''cube4-review-v1''','''cube4-review-v2-exact''');EXECUTE definition;
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 definition:=replace(definition,'''engine'',''cube4-review-v1'',''period''','''engine'',''cube4-review-v2-exact'',''legal_employer'',(SELECT jsonb_build_object(''display_name'',display_name,''legal_name'',legal_name,''is_active'',is_active) FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer),''period''');
 IF definition NOT LIKE '%legal_employer%' THEN RAISE EXCEPTION 'unexpected_manifest_identity';END IF;EXECUTE definition;
 definition:=pg_get_functiondef('public.payroll_run_command(uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);EXECUTE replace(definition,'''cube4-review-v1''','''cube4-review-v2-exact''');
 definition:=pg_get_functiondef('payroll.stale_reasons(jsonb,jsonb)'::regprocedure);EXECUTE replace(definition,'ARRAY[''period'',''employees''','ARRAY[''engine'',''legal_employer'',''period'',''employees''');
 definition:=pg_get_functiondef('payroll.review_segments(jsonb)'::regprocedure);definition:=replace(definition,'p-''date''','p-''_numerator''-''_denominator''-''date''');definition:=replace(definition,'p - ''date''','p - ''_numerator'' - ''_denominator'' - ''date''');IF definition NOT LIKE '%_numerator%' THEN RAISE EXCEPTION 'unexpected_detail_projection';END IF;EXECUTE definition;
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;
-- Supersession links must remain in the same legal Employer and actual period; no public route is open yet.
CREATE FUNCTION payroll.guard_output_succession_scope() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE old_output payroll.final_contexts%ROWTYPE;new_output payroll.final_contexts%ROWTYPE;BEGIN
 SELECT * INTO old_output FROM payroll.final_contexts WHERE tenant_id=NEW.tenant_id AND id=NEW.original_output;
 SELECT * INTO new_output FROM payroll.final_contexts WHERE tenant_id=NEW.tenant_id AND id=NEW.replacement_output;
 IF old_output.id IS NULL OR new_output.id IS NULL OR(old_output.employer_id,old_output.period_id) IS DISTINCT FROM(new_output.employer_id,new_output.period_id) THEN RAISE EXCEPTION 'payroll_output_scope' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $f$;
CREATE TRIGGER payroll_output_succession_scope BEFORE INSERT ON payroll.output_successions FOR EACH ROW EXECUTE FUNCTION payroll.guard_output_succession_scope();
REVOKE ALL ON FUNCTION payroll.guard_output_succession_scope() FROM PUBLIC,anon,authenticated,service_role;
