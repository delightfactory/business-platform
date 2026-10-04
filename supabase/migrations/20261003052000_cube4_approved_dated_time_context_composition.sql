-- Actual approved dated Time/Leave payable parts can use the already issued
-- chronological prefix rule. Manual aggregate totals remain undated evidence.
DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('payroll.current_earning_sources(jsonb)'::regprocedure);
 anchor:='WHEN line->>''component''=''base'' AND p_employee->>''pay_basis''=''daily'' THEN ''preserved_daily_source_basis''';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_time_dated_earning_source';END IF;
 EXECUTE replace(definition,anchor,'WHEN line->>''component''=''base'' AND p_employee->>''pay_basis''=''daily'' THEN CASE WHEN p_employee->''source_summary''->>''selected_source''=''time'' AND p_employee->''source_summary''->>''operational_complete''=''true'' THEN ''approved_dated_payable_source'' ELSE ''preserved_daily_source_basis'' END');
 definition:=pg_get_functiondef('payroll.earning_date_partitions(jsonb)'::regprocedure);
 anchor:='parts:=line->''source_parts'';';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_time_partition_source_parts';END IF;
 definition:=replace(definition,anchor,$insert$
SELECT coalesce(jsonb_agg((outer_item.envelope-'detail'-'raw')||inner_item.part ORDER BY outer_item.outer_index,inner_item.inner_index),'[]') INTO parts
 FROM jsonb_array_elements(line->'source_parts') WITH ORDINALITY outer_item(envelope,outer_index)
 CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(outer_item.envelope->'detail')='array'
  THEN outer_item.envelope->'detail' ELSE jsonb_build_array(outer_item.envelope) END) WITH ORDINALITY inner_item(part,inner_index);$insert$);
 anchor:='known:=line->>''attribution''=''saved_salary_distribution'';';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_time_partition_attribution';END IF;
 EXECUTE replace(definition,anchor,'known:=line->>''attribution'' IN(''saved_salary_distribution'',''approved_dated_payable_source'');');
 definition:=pg_get_functiondef('payroll.reviewed_earning_segment(jsonb,date,date)'::regprocedure);
 anchor:='source->>''attribution'' IS DISTINCT FROM ''saved_salary_distribution''';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_time_segment_attribution';END IF;
 EXECUTE replace(definition,anchor,'coalesce(source->>''attribution'','''') NOT IN(''saved_salary_distribution'',''approved_dated_payable_source'')');
 definition:=pg_get_functiondef('payroll.compose_reviewed_statutory_segments(jsonb,jsonb)'::regprocedure);
 anchor:='p_employee->>''pay_basis''<>''monthly''';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_time_segment_pay_basis';END IF;
 definition:=replace(definition,anchor,'p_employee->>''pay_basis'' NOT IN(''monthly'',''daily'')');
 anchor:='OR coalesce((p_manifest->''optional''->>''time'')::boolean,false) OR coalesce((p_manifest->''optional''->>''leave'')::boolean,false)';
 IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_time_segment_optional_guard';END IF;
 EXECUTE replace(definition,anchor,'OR NOT payroll.daily_optional_financial_profile(p_manifest,p_employee)');
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:=' RETURN m||';IF position(anchor IN definition)=0 THEN RAISE EXCEPTION 'unexpected_time_segment_manifest';END IF;
 EXECUTE replace(definition,anchor,' m:=m||jsonb_build_object(''engine'',(m->>''engine'')||''-approved-dated-time-segments-v1'');'||anchor);
END $patch$;
