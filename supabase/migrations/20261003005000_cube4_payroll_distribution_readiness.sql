-- A payslip or payroll sheet is also a financial distribution. Reuse the
-- frozen statutory-pack readiness boundary, never infer readiness from totals.
DO $f$ DECLARE definition text;anchor text:='IF p_report=''payslip'' AND EXISTS';BEGIN
 definition:=pg_get_functiondef('public.payroll_report_workspace(uuid,uuid,uuid,text,uuid,uuid,text,uuid,integer,text,boolean,uuid,uuid)'::regprocedure);
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_payroll_distribution_guard';END IF;
 EXECUTE replace(definition,anchor,'IF p_report IN(''sheet'',''payslip'') AND (
  NOT EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.manifest->''packs'')=''array'' THEN c.manifest->''packs'' ELSE ''[]''::jsonb END) pack WHERE pack->>''state''=''verified'')
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.manifest->''packs'')=''array'' THEN c.manifest->''packs'' ELSE ''[]''::jsonb END) pack WHERE pack->>''state'' IS DISTINCT FROM ''verified'')
 ) THEN issues:=issues||''"statutory_pack_unqualified"''::jsonb;END IF; '||anchor);
END $f$;
