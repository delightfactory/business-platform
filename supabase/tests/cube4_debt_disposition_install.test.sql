BEGIN;
DO $$BEGIN IF current_database()<>'business_platform_cube4_adam_positive_qa' THEN RAISE EXCEPTION 'Owned QA required';END IF;END$$;
SELECT no_plan();
SELECT ok(to_regclass('payroll.deduction_dispositions') IS NOT NULL,'explicit approved residual ledger exists');
SELECT ok(NOT has_table_privilege('authenticated','payroll.deduction_dispositions','SELECT'),'debt ledger has no direct authenticated table exposure');
SELECT ok(has_function_privilege('authenticated','public.payroll_deduction_disposition(uuid,uuid,uuid,uuid,uuid,integer,uuid,text,numeric,text,uuid,date,text,text,uuid)','EXECUTE'),'approved disposition public entry is callable');
SELECT ok(NOT has_function_privilege('authenticated','public.payroll_save_input_before_recurring_debts(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid)','EXECUTE'),'legacy writer cannot bypass recurring financial approval');
SELECT * FROM finish();ROLLBACK;
