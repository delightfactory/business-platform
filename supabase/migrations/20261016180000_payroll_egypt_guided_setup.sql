CREATE OR REPLACE FUNCTION public.payroll_egypt_setup_context(p_tenant uuid,p_employer uuid,p_period uuid,p_employment uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE h people.employments;bounds payroll.periods;starts date;ends date;pack payroll.statutory_packs;matches integer;
 context_record jsonb;opening_record jsonb;prior boolean;duration integer;policy_exists boolean;
BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll.prepare',false);
 SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 SELECT * INTO h FROM people.employments WHERE tenant_id=p_tenant AND employer_entity_id=p_employer AND id=p_employment AND payroll_eligible;
 IF NOT FOUND OR h.start_date>bounds.ends_on OR coalesce(h.end_date,bounds.ends_on)<bounds.starts_on THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 starts:=greatest(bounds.starts_on,h.start_date);ends:=least(bounds.ends_on,coalesce(h.end_date,bounds.ends_on));
 SELECT count(*) INTO matches FROM payroll.statutory_packs WHERE state='verified' AND engine_adapter='eg-cumulative-tax-v1'
  AND rules->>'tax_treatment_code'='01' AND effective_from<=starts AND(effective_until IS NULL OR effective_until>ends);
 IF matches=1 THEN SELECT * INTO pack FROM payroll.statutory_packs WHERE state='verified' AND engine_adapter='eg-cumulative-tax-v1'
  AND rules->>'tax_treatment_code'='01' AND effective_from<=starts AND(effective_until IS NULL OR effective_until>ends);END IF;
 IF (SELECT count(*) FROM payroll.input_heads WHERE tenant_id=p_tenant AND employment_id=h.id AND kind='statutory_context')>1 THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409';END IF;
 SELECT jsonb_build_object('id',ih.id,'revision',ih.revision,'data',v.data,'effective_from',v.effective_from,'effective_until',v.effective_until,'status',v.status)
 INTO context_record FROM payroll.input_heads ih JOIN payroll.input_versions v ON v.tenant_id=ih.tenant_id AND v.head_id=ih.id AND v.revision=ih.revision
 WHERE ih.tenant_id=p_tenant AND ih.employment_id=h.id AND ih.kind='statutory_context';
 SELECT jsonb_build_object('id',ih.id,'revision',ih.revision,'data',v.data,'effective_from',v.effective_from,'effective_until',v.effective_until,'status',v.status)
 INTO opening_record FROM payroll.input_heads ih CROSS JOIN LATERAL(SELECT * FROM payroll.input_versions iv WHERE iv.tenant_id=ih.tenant_id AND iv.head_id=ih.id AND iv.effective_from<=starts ORDER BY iv.effective_from DESC,iv.revision DESC LIMIT 1)v
 WHERE ih.tenant_id=p_tenant AND ih.employer_id=p_employer AND ih.kind='opening_ytd' AND v.status IN('draft','approved','applied') AND(v.effective_until IS NULL OR v.effective_until>starts) AND v.data->>'year'=extract(year FROM starts)::text
  AND ih.employment_id IN(SELECT id FROM people.employments WHERE tenant_id=p_tenant AND employer_entity_id=p_employer AND employee_id=h.employee_id)
 ORDER BY v.effective_from DESC,v.revision DESC LIMIT 1;
 prior:=jsonb_array_length(payroll.prior_statutory_outputs(p_tenant,p_employer,starts,ends,ARRAY[h.employee_id]))>0;
 IF h.pay_basis='monthly' AND date_trunc('month',starts)=date_trunc('month',ends) THEN
  duration:=CASE WHEN extract(day FROM starts)=1 AND ends=(date_trunc('month',ends)+interval '1 month - 1 day')::date THEN 30 ELSE least(30,ends-starts+1) END;
 END IF;
 policy_exists:=EXISTS(SELECT 1 FROM payroll.input_heads WHERE tenant_id=p_tenant AND kind='policy');
 RETURN jsonb_build_object('starts_on',starts,'ends_on',ends,'pay_basis',h.pay_basis,'employment_start',h.start_date,
 'single_month',date_trunc('month',starts)=date_trunc('month',ends),'suggested_duration',duration,
 'full_month',extract(day FROM starts)=1 AND ends=(date_trunc('month',ends)+interval '1 month - 1 day')::date,
 'pack',CASE WHEN pack.id IS NOT NULL THEN jsonb_build_object('version',pack.version,'category',pack.insurance_rules->>'category','minimum',pack.insurance_rules->'wage_minimum','maximum',pack.insurance_rules->'wage_maximum') END,
 'locked',EXISTS(SELECT 1 FROM payroll.people_frozen_contexts fc JOIN payroll.periods fp ON fp.tenant_id=fc.tenant_id AND fp.id=fc.period_id WHERE fc.tenant_id=p_tenant AND fc.employment_id=h.id AND daterange(fp.starts_on,fp.ends_on,'[]')&&daterange(starts,ends,'[]')),'context',context_record,'opening',opening_record,'prior_final',prior,'policy_exists',policy_exists,
 'stamp',md5(jsonb_build_array(to_jsonb(h),to_jsonb(bounds),to_jsonb(pack),context_record,opening_record,prior)::text));
END $f$;

CREATE OR REPLACE FUNCTION public.payroll_prepare_egypt_employee(p_tenant uuid,p_employer uuid,p_period uuid,p_employment uuid,p_stamp text,p_choices jsonb,p_attempt uuid) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;facts jsonb;intent jsonb;receipt payroll.command_receipts;data jsonb;opening_data jsonb;context_result jsonb;opening_result jsonb;
 starts date;ends date;month_on date;insured boolean;disposition text;duration numeric;reference text:='إعداد الرواتب المصري — اختيار الشركة';
BEGIN
 actor:=payroll.authorized(p_tenant,'payroll.prepare',true);
 PERFORM payroll.lock_input_scope(p_tenant,p_employer,p_employment);
 actor:=payroll.authorized(p_tenant,'payroll.prepare',true);
 IF p_attempt IS NULL OR jsonb_typeof(p_choices) IS DISTINCT FROM 'object' OR p_stamp IS NULL THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 intent:=jsonb_build_object('operation','egypt_employee_setup','employer',p_employer,'period',p_period,'employment',p_employment,'stamp',p_stamp,'choices',p_choices);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 facts:=public.payroll_egypt_setup_context(p_tenant,p_employer,p_period,p_employment);
 IF facts->>'stamp' IS DISTINCT FROM p_stamp THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409';END IF;
 IF facts->>'single_month' IS DISTINCT FROM 'true' OR facts->'pack'='null'::jsonb THEN RAISE EXCEPTION 'payroll_egypt_scope_unavailable' USING ERRCODE='22023';END IF;
 starts:=(facts->>'starts_on')::date;ends:=(facts->>'ends_on')::date;month_on:=date_trunc('month',starts)::date;
 IF p_choices->>'insurance_status' NOT IN('insured','not_insured') OR p_choices->>'insurance_status' IS NULL THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 insured:=p_choices->>'insurance_status'='insured';
 duration:=coalesce(nullif(p_choices->>'tax_duration_days','')::numeric,(facts->>'suggested_duration')::numeric);
 IF duration IS NULL OR duration NOT BETWEEN 0.01 AND 30 THEN RAISE EXCEPTION 'payroll_egypt_duration_required' USING ERRCODE='22023';END IF;
 -- Existing special context is retained, then only the explicit visible choices
 -- and selected employee-period scope are changed. No opening is overwritten.
 data:=coalesce(nullif(facts->'context'->'data','null'::jsonb),'{}'::jsonb)
  -ARRAY['insurance_category','insured_wage','insurance_from','insurance_until','insurance_obligation_month','insurance_owner_period','insurance_obligation_reference','insurance_month_disposition'];
 data:=data||jsonb_build_object('tax_treatment_code',coalesce(nullif(p_choices->>'tax_treatment_code',''),data->>'tax_treatment_code','01'),
  'insurance_status',p_choices->>'insurance_status','reference',reference,'reason','حفظ إعداد الموظف بالأساس المصري بعد مراجعة اختيارات الشركة',
  'calculation_from',starts,'calculation_until',ends,'tax_duration_days',duration);
 IF insured THEN
  disposition:=nullif(p_choices->>'insurance_month_disposition','');
  IF disposition IS NULL AND facts->>'full_month'='true' THEN disposition:='reviewed_due';END IF;
  IF disposition IS NULL OR disposition NOT IN('reviewed_due','reviewed_not_due') THEN RAISE EXCEPTION 'payroll_egypt_insurance_choice_required' USING ERRCODE='22023';END IF;
  data:=data||jsonb_build_object('insurance_category',coalesce(nullif(p_choices->>'insurance_category',''),facts->'pack'->>'category'),
   'insured_wage',p_choices->>'insured_wage','insurance_from',p_choices->>'insurance_from',
   'insurance_obligation_month',month_on,'insurance_owner_period',p_period,'insurance_obligation_reference',reference,'insurance_month_disposition',disposition);
  IF nullif(p_choices->>'insurance_until','') IS NOT NULL THEN data:=data||jsonb_build_object('insurance_until',p_choices->>'insurance_until');END IF;
 END IF;
 context_result:=public.payroll_save_input(p_tenant,p_employer,'statutory_context',p_employment,NULL,
  (facts->'context'->>'id')::uuid,coalesce((facts->'context'->>'revision')::integer,0),starts,ends+1,data,'save',md5(p_attempt::text||':context')::uuid);
 IF facts->'opening'='null'::jsonb AND facts->>'prior_final'='false' THEN
  IF p_choices->>'no_prior_income' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'payroll_egypt_opening_required' USING ERRCODE='22023';END IF;
  opening_data:=jsonb_build_object('year',extract(year FROM starts)::integer,'taxable_earnings',0,'tax_withheld',0,'tax_due',0,'tax_net_income',0,'social_base',0,'employee_social',0,'employer_social',0,
   'reference',reference,'reason','أكدت الشركة عدم وجود دخل أو أرصدة سابقة للموظف في هذه السنة');
  IF starts>date_trunc('year',starts)::date THEN opening_data:=opening_data||jsonb_build_object('coverage_start',date_trunc('year',starts)::date,'coverage_end',starts-1,'tax_duration_days',0);END IF;
  opening_result:=public.payroll_save_input(p_tenant,p_employer,'opening_ytd',p_employment,NULL,NULL,0,starts,NULL,opening_data,'save',md5(p_attempt::text||':opening')::uuid);
 END IF;
 receipt.result:=jsonb_build_object('context',context_result,'opening',opening_result,'saved',true);
 INSERT INTO payroll.command_receipts(tenant_id,actor_id,attempt_key,intent,result) VALUES(p_tenant,actor,p_attempt,intent,receipt.result);
 PERFORM payroll.authorized(p_tenant,'payroll.prepare',true);
 RETURN receipt.result;
END $f$;
REVOKE ALL ON FUNCTION public.payroll_egypt_setup_context(uuid,uuid,uuid,uuid),public.payroll_prepare_egypt_employee(uuid,uuid,uuid,uuid,text,jsonb,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_egypt_setup_context(uuid,uuid,uuid,uuid),public.payroll_prepare_egypt_employee(uuid,uuid,uuid,uuid,text,jsonb,uuid) TO authenticated;
