BEGIN;
SELECT no_plan();
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
('f5000000-0000-4000-8000-000000000001','cube5-p1-operator@example.test','',now(),'{}','{}','authenticated','authenticated',now(),now()),
('f5000000-0000-4000-8000-000000000002','cube5-p1-employee@example.test','',now(),'{}','{}','authenticated','authenticated',now(),now());
\ir ../../scripts/cube5-qa-fixture.sql
SELECT set_config('test.p1_fixture',pg_temp.seed_cube5_fixture('f5000000-0000-4000-8000-000000000001','f5000000-0000-4000-8000-000000000002')::text,true);
SELECT set_config('test.p1_tenant',current_setting('test.p1_fixture')::jsonb->>'tenant_id',true);
-- Align the fixture's business date with the existing People transfer RPC date, without clock/global changes.
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,required_minutes,earliest_punch,latest_punch,created_by) VALUES
(current_setting('test.p1_tenant')::uuid,'f5150000-0000-4000-8000-000000000001',2,'P1 work context','flexible','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],60,'00:00','23:59:59','f5000000-0000-4000-8000-000000000001'),
(current_setting('test.p1_tenant')::uuid,'f5150000-0000-4000-8000-000000000001',3,'P1 revised work context','flexible','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],90,'00:00','23:59:59','f5000000-0000-4000-8000-000000000001');
UPDATE people.work_assignments SET work_policy_version=2 WHERE tenant_id=current_setting('test.p1_tenant')::uuid;
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active) VALUES
(current_setting('test.p1_tenant')::uuid,'f5140000-0000-4000-8000-000000000002','f5130000-0000-4000-8000-000000000001','P1 Site B',false,true);
SELECT set_config('test.p1_source_b',public.attendance_channel_save_source(current_setting('test.p1_tenant')::uuid,NULL,'P1 mobile B','mobile','f5140000-0000-4000-8000-000000000002',true,'{"geofence":false,"retention_seconds":300}','P1 exact context fixture')::text,true);
SELECT set_config('request.jwt.claim.sub','f5000000-0000-4000-8000-000000000002',true);
SELECT set_config('test.p1_a',public.attendance_mobile_snapshot(current_setting('test.p1_tenant')::uuid)::text,true);
SELECT set_config('test.p1_unsaved_a',jsonb_build_object('id','f5600000-0000-4000-8000-000000000011','direction','in','happened_at',now(),'scope',current_setting('test.p1_a')::jsonb->>'scope','policy_version',1,'location',NULL)::text,true);
SELECT is(current_setting('test.p1_a')::jsonb->>'policy_version','1','Site A source is version one');
SELECT is(current_setting('test.p1_a')::jsonb ? 'capture_context',false,'public snapshot omits internal capture context identifiers');
-- A prior-day authoritative receipt is created as immutable history through the real gateway.
-- A materialized current-day receipt correctly prevents a same-day People transfer; this fixture respects that guard.
SELECT set_config('test.p1_saved_a',jsonb_build_object('id','f5600000-0000-4000-8000-000000000012','direction','in','happened_at',now()-interval '1 day','scope',current_setting('test.p1_a')::jsonb->>'scope','policy_version',1,'location',NULL)::text,true);
INSERT INTO time.channel_events(tenant_id,source_id,source_version,event_key,external_key,direction,happened_at,payload_fingerprint,actor_user_id,employee_id,site_id,link_id,scope,validation,capture_context)
SELECT current_setting('test.p1_tenant')::uuid,(current_setting('test.p1_fixture')::jsonb->>'mobile_source_id')::uuid,1,current_setting('test.p1_saved_a')::jsonb->>'id',l.employee_id::text,'in',now()-interval '1 day',md5(current_setting('test.p1_saved_a')::jsonb::text),l.user_id,l.employee_id,'f5140000-0000-4000-8000-000000000001',l.id,current_setting('test.p1_a')::jsonb->>'scope','not_required',time.mobile_context(l.tenant_id)->'capture_context'
FROM people.employee_user_links l WHERE l.tenant_id=current_setting('test.p1_tenant')::uuid AND l.user_id='f5000000-0000-4000-8000-000000000002' AND l.unlinked_at IS NULL;
SELECT set_config('test.p1_saved_event',(SELECT id::text FROM time.channel_events WHERE tenant_id=current_setting('test.p1_tenant')::uuid),true);
SELECT is(time.channel_process(current_setting('test.p1_tenant')::uuid,current_setting('test.p1_saved_event')::uuid,'f5000000-0000-4000-8000-000000000002')->>'state','accepted','prior-day source A receipt has real canonical Time evidence');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','f5000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.p1_transfer',public.schedule_people_work_assignment(current_setting('test.p1_tenant')::uuid,(current_setting('test.p1_fixture')::jsonb->>'employment_id')::uuid,(now() AT TIME ZONE 'Africa/Cairo')::date,'f5140000-0000-4000-8000-000000000002',NULL,NULL,NULL)::text,true);
SELECT is(current_setting('test.p1_transfer')::jsonb->>'state','transferred','actual public People transition moves the effective assignment to B');
SELECT set_config('request.jwt.claim.sub','f5000000-0000-4000-8000-000000000002',true);
SELECT set_config('test.p1_b',public.attendance_mobile_snapshot(current_setting('test.p1_tenant')::uuid)::text,true);
SELECT is(current_setting('test.p1_b')::jsonb->>'policy_version','1','Site B source also has version one');
SELECT is(current_setting('test.p1_b')::jsonb->>'site_name','P1 Site B','snapshot actually derives Site B');
SELECT isnt(current_setting('test.p1_b')::jsonb->>'scope',current_setting('test.p1_a')::jsonb->>'scope','distinct trusted assignment and source changes pending scope despite equal version numbers');
SELECT is(public.attendance_mobile_punch(current_setting('test.p1_tenant')::uuid,current_setting('test.p1_unsaved_a')::jsonb)->>'reason','scope_changed','unsaved A attempt cannot silently become a B punch');
SELECT is(public.attendance_mobile_attempt(current_setting('test.p1_tenant')::uuid,'f5600000-0000-4000-8000-000000000011',current_setting('test.p1_a')::jsonb->>'scope')->>'reason','scope_changed','absent old-context reconciliation never reattributes or claims a current-context receipt');
SELECT is(public.attendance_mobile_punch(current_setting('test.p1_tenant')::uuid,current_setting('test.p1_saved_a')::jsonb)->>'state','duplicate','legitimate older A receipt replays under the same current authorized link after transfer');
SELECT is(public.attendance_mobile_attempt(current_setting('test.p1_tenant')::uuid,'f5600000-0000-4000-8000-000000000012',current_setting('test.p1_a')::jsonb->>'scope')->>'state','accepted','older A receipt reconciles after current context has moved to B');
SELECT is(public.attendance_mobile_punch(current_setting('test.p1_tenant')::uuid,current_setting('test.p1_saved_a')::jsonb||'{"direction":"out"}')->>'reason','conflict','old receipt replay still requires exact saved payload');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM time.channel_events WHERE tenant_id=current_setting('test.p1_tenant')::uuid),1,'stale A requests and legitimate replay add no source events');
SELECT is((SELECT count(*)::integer FROM time.manual_punches WHERE tenant_id=current_setting('test.p1_tenant')::uuid),1,'stale A requests and replay add no canonical punches');
SELECT set_config('test.p1_b_pre_policy',jsonb_build_object('id','f5600000-0000-4000-8000-000000000013','direction','in','happened_at',now(),'scope',current_setting('test.p1_b')::jsonb->>'scope','policy_version',1,'location',NULL)::text,true);
-- Trusted fixture mutation of the SAME assignment ID demonstrates why relevant fields must also be bound.
UPDATE people.work_assignments SET work_policy_version=3 WHERE tenant_id=current_setting('test.p1_tenant')::uuid AND id=(current_setting('test.p1_transfer')::jsonb->>'assignment_id')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('test.p1_b_work_revised',public.attendance_mobile_snapshot(current_setting('test.p1_tenant')::uuid)::text,true);
SELECT isnt(current_setting('test.p1_b_work_revised')::jsonb->>'scope',current_setting('test.p1_b')::jsonb->>'scope','same assignment ID with a new Time policy version changes pending scope');
SELECT is(public.attendance_mobile_punch(current_setting('test.p1_tenant')::uuid,current_setting('test.p1_b_pre_policy')::jsonb)->>'reason','scope_changed','stale Time policy context is rejected before receipt/canonical insertion');
SELECT set_config('test.p1_b_pre_source',jsonb_build_object('id','f5600000-0000-4000-8000-000000000014','direction','in','happened_at',now(),'scope',current_setting('test.p1_b_work_revised')::jsonb->>'scope','policy_version',1,'location',NULL)::text,true);
SELECT set_config('request.jwt.claim.sub','f5000000-0000-4000-8000-000000000001',true);
SELECT lives_ok($$SELECT public.attendance_channel_save_source(current_setting('test.p1_tenant')::uuid,current_setting('test.p1_source_b')::uuid,'P1 mobile B','mobile','f5140000-0000-4000-8000-000000000002',true,'{"geofence":false,"retention_seconds":600}','P1 revised source policy')$$,'source configuration changes in a forward version');
SELECT set_config('request.jwt.claim.sub','f5000000-0000-4000-8000-000000000002',true);
SELECT set_config('test.p1_b_final',public.attendance_mobile_snapshot(current_setting('test.p1_tenant')::uuid)::text,true);
SELECT is(current_setting('test.p1_b_final')::jsonb->>'scope',current_setting('test.p1_b_work_revised')::jsonb->>'scope','same source version update leaves identity scope unchanged');
SELECT is(public.attendance_mobile_punch(current_setting('test.p1_tenant')::uuid,current_setting('test.p1_b_pre_source')::jsonb)->>'reason','policy_changed','existing source policy_changed behavior is preserved');
SELECT set_config('test.p1_b_fresh',jsonb_build_object('id','f5600000-0000-4000-8000-000000000015','direction','in','happened_at',now(),'scope',current_setting('test.p1_b_final')::jsonb->>'scope','policy_version',2,'location',NULL)::text,true);
SELECT is(public.attendance_mobile_punch(current_setting('test.p1_tenant')::uuid,current_setting('test.p1_b_fresh')::jsonb)->>'state','accepted','fresh B attempt records against B context and revised policies');
SELECT is(public.attendance_mobile_punch(current_setting('test.p1_tenant')::uuid,current_setting('test.p1_saved_a')::jsonb)->>'state','duplicate','old A receipt remains idempotent after both Time and source policy changes');
RESET ROLE;
SELECT is((SELECT count(*)::integer FROM time.channel_events WHERE tenant_id=current_setting('test.p1_tenant')::uuid),2,'only historical A and fresh B source events exist');
SELECT is((SELECT count(*)::integer FROM time.manual_punches WHERE tenant_id=current_setting('test.p1_tenant')::uuid),2,'exactly two distinct canonical punches exist');
SELECT is((SELECT source_id FROM time.channel_events WHERE tenant_id=current_setting('test.p1_tenant')::uuid AND event_key='f5600000-0000-4000-8000-000000000015'),current_setting('test.p1_source_b')::uuid,'fresh receipt retains exact B source identity');
SELECT is((SELECT capture_context->>'assignment_id' FROM time.channel_events WHERE tenant_id=current_setting('test.p1_tenant')::uuid AND event_key='f5600000-0000-4000-8000-000000000015'),current_setting('test.p1_transfer')::jsonb->>'assignment_id','fresh receipt retains exact trusted assignment');
SELECT is((SELECT capture_context->>'work_policy_version' FROM time.channel_events WHERE tenant_id=current_setting('test.p1_tenant')::uuid AND event_key='f5600000-0000-4000-8000-000000000015'),'3','fresh receipt freezes the effective Time policy version');
SELECT is((SELECT i.site_id FROM time.manual_punches p JOIN time.work_instances i ON i.tenant_id=p.tenant_id AND i.id=p.work_instance_id WHERE p.tenant_id=current_setting('test.p1_tenant')::uuid AND i.operational_date=(now() AT TIME ZONE 'Africa/Cairo')::date),'f5140000-0000-4000-8000-000000000002'::uuid,'new canonical Time flow is bound to B Site');
SELECT is((SELECT source_id FROM time.channel_events WHERE tenant_id=current_setting('test.p1_tenant')::uuid AND id=current_setting('test.p1_saved_event')::uuid),(current_setting('test.p1_fixture')::jsonb->>'mobile_source_id')::uuid,'older A provenance is never rewritten to B');
-- Relinking the same account does not authorize access through a previous EmployeeUser link identity.
UPDATE people.employee_user_links SET unlinked_at=now(),unlinked_by_user_id='f5000000-0000-4000-8000-000000000001' WHERE tenant_id=current_setting('test.p1_tenant')::uuid AND user_id='f5000000-0000-4000-8000-000000000002' AND unlinked_at IS NULL;
INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id) VALUES(current_setting('test.p1_tenant')::uuid,(current_setting('test.p1_fixture')::jsonb->>'employee_id')::uuid,'f5000000-0000-4000-8000-000000000002','f5000000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SELECT is(public.attendance_mobile_punch(current_setting('test.p1_tenant')::uuid,current_setting('test.p1_saved_a')::jsonb)->>'reason','scope_changed','old receipt cannot be replayed through a different current link');
SELECT is(public.attendance_mobile_attempt(current_setting('test.p1_tenant')::uuid,'f5600000-0000-4000-8000-000000000012',current_setting('test.p1_a')::jsonb->>'scope')->>'reason','scope_changed','old receipt cannot be reconciled through a different current link');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
