BEGIN;
SELECT no_plan();
SELECT set_config('test.today',((now() AT TIME ZONE 'Africa/Cairo')::date)::text,true);

INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at)
VALUES ('cf910000-0000-4000-8000-000000000001','leave-recovery-hr@example.test','hash',now(),'{}','{}','authenticated','authenticated',now(),now());
INSERT INTO platform_core.tenants(id,display_name,created_by_operator_id)
VALUES ('cf920000-0000-4000-8000-000000000001','Leave recovery tenant','cf910000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_roles(tenant_id,role_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
VALUES ('cf920000-0000-4000-8000-000000000001','cf930000-0000-4000-8000-000000000001','test.leave.recovery.hr.v1',1,ARRAY['leave.manage','leave.view'],false);
INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,created_by_operator_id)
VALUES ('cf920000-0000-4000-8000-000000000001','cf910000-0000-4000-8000-000000000001','cf910000-0000-4000-8000-000000000001');
INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id)
VALUES ('cf920000-0000-4000-8000-000000000001','cf910000-0000-4000-8000-000000000001','cf930000-0000-4000-8000-000000000001');
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001','Employer Recovery',true);
INSERT INTO platform_core.tenant_legal_entities(tenant_id,id,display_name,is_default)
VALUES ('cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000002','Employer Coverage Guard',false);
INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,actor_user_id,reason)
VALUES ('cf920000-0000-4000-8000-000000000001','hr.people',true,now()-interval '1 minute','cf910000-0000-4000-8000-000000000001','configuration recovery'),
       ('cf920000-0000-4000-8000-000000000001','hr.leave',true,now()-interval '1 minute','cf910000-0000-4000-8000-000000000001','configuration recovery');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','cf910000-0000-4000-8000-000000000001',true);
SELECT set_config('test.today',current_setting('test.today'),true);

-- Calendar has an already configured period, an initial snapshot, and a later planned version.
SELECT set_config('test.calendar',public.leave_create_calendar(
 'cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001',
 'scheduled','Scheduled calendar',current_setting('test.today')::date-5,NULL,ARRAY[5,6]::smallint[],
 jsonb_build_array(jsonb_build_object('date',(current_setting('test.today')::date-2)::text,'name','Original holiday')),
 'Initial calendar source','Initial effective snapshot')::text,true);
SELECT public.leave_create_year_period(
 'cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001',
 current_setting('test.calendar')::uuid,current_setting('test.today')::date-5,current_setting('test.today')::date+45,
 'Scheduled recovery period','Configured period for recovery tests');
SELECT set_config('test.calendar_scheduled',public.leave_revise_calendar(
 'cf920000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
 current_setting('test.today')::date+30,NULL,ARRAY[5,6]::smallint[],
 jsonb_build_array(jsonb_build_object('date',(current_setting('test.today')::date+35)::text,'name','Scheduled holiday')),
 'Planned calendar','Future version scheduled before the urgent change')::text,true);
SELECT lives_ok(format($q$SELECT public.leave_revise_calendar(
 'cf920000-0000-4000-8000-000000000001','%s',
 (current_setting('test.today')::date+10),NULL,ARRAY[0,1]::smallint[],
 jsonb_build_array(jsonb_build_object('date',(current_setting('test.today')::date+15)::text,'name','Urgent holiday')),
 'Urgent calendar','Prospective revision before an already scheduled version')$q$,
 current_setting('test.calendar')),
 'urgent calendar revision can be inserted before a later scheduled version');
SELECT set_config('test.calendar_versions',(
 SELECT c->'versions' FROM jsonb_array_elements(public.leave_configuration_snapshot(
  'cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001')->'calendars') c
 WHERE c->>'calendar_id'=current_setting('test.calendar'))::text,true);
SELECT set_config('test.calendar_urgent',(
 SELECT v->>'id' FROM jsonb_array_elements(current_setting('test.calendar_versions')::jsonb) v WHERE v->>'version'='3'),true);
SELECT is((SELECT v->>'version' FROM jsonb_array_elements(current_setting('test.calendar_versions')::jsonb) v WHERE v->>'id'=current_setting('test.calendar_urgent')),'3',
 'inserted calendar snapshot uses max version plus one');
SELECT is(public.leave_calendar_day('cf920000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
 current_setting('test.today')::date-2)->>'holiday','Original holiday',
 'date before urgent version retains original holiday snapshot');
SELECT is(public.leave_calendar_day('cf920000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
 current_setting('test.today')::date+15)->>'holiday','Urgent holiday',
 'date in inserted interval resolves its own immutable holiday snapshot');
SELECT is(public.leave_calendar_day('cf920000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
 current_setting('test.today')::date+35)->>'holiday','Scheduled holiday',
 'later scheduled version remains effective after the inserted interval');
SELECT is((SELECT v->>'effective_until' FROM jsonb_array_elements(current_setting('test.calendar_versions')::jsonb) v WHERE v->>'id'=current_setting('test.calendar_urgent')),
 (current_setting('test.today')::date+30)::text,'inserted calendar version ends at the next scheduled boundary');

SELECT throws_ok(format($q$SELECT public.leave_revise_calendar(
 'cf920000-0000-4000-8000-000000000001','%s',(current_setting('test.today')::date+12),
 (current_setting('test.today')::date+40),ARRAY[0,1]::smallint[],'[]'::jsonb,
 'Crossing version','Must not overlap the already scheduled boundary')$q$,
 current_setting('test.calendar')),'23P01','leave_calendar_revision_invalid',
 'calendar revision that crosses a later scheduled boundary is rejected');
SELECT throws_ok(format($q$SELECT public.leave_revise_calendar(
 'cf920000-0000-4000-8000-000000000001','%s',(current_setting('test.today')::date+30),
 NULL,ARRAY[0,1]::smallint[],'[]'::jsonb,'Same start','Same-start replacement is not implicit')$q$,
 current_setting('test.calendar')),'23P01','leave_calendar_revision_invalid',
 'same-start replacement of a planned calendar version remains an explicit conflict');
SELECT is(public.leave_calendar_day('cf920000-0000-4000-8000-000000000001',current_setting('test.calendar')::uuid,
 current_setting('test.today')::date+15)->>'holiday','Urgent holiday',
 'rejected calendar edits leave the accepted date snapshot unchanged');

-- An expired finite snapshot is never reopened; its old gap remains uncovered.
SELECT set_config('test.expired_calendar',public.leave_create_calendar(
 'cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001',
 'expired','Expired finite calendar',current_setting('test.today')::date-30,current_setting('test.today')::date-10,
 ARRAY[5,6]::smallint[],jsonb_build_array(jsonb_build_object('date',(current_setting('test.today')::date-20)::text,'name','Expired-era holiday')),
 'Finite source','Finite version deliberately expired')::text,true);
SELECT lives_ok(format($q$SELECT public.leave_revise_calendar(
 'cf920000-0000-4000-8000-000000000001','%s',(current_setting('test.today')::date+5),NULL,
 ARRAY[0,1]::smallint[],jsonb_build_array(jsonb_build_object('date',(current_setting('test.today')::date+7)::text,'name','Resumed holiday')),
 'Resumed source','Resume future configuration without rewriting expired range')$q$,
 current_setting('test.expired_calendar')),
 'expired finite calendar can receive a future version');
SELECT is(public.leave_calendar_day('cf920000-0000-4000-8000-000000000001',current_setting('test.expired_calendar')::uuid,
 current_setting('test.today')::date-20)->>'holiday','Expired-era holiday',
 'resuming an expired calendar preserves historical holiday evidence');
SELECT is(public.leave_calendar_day('cf920000-0000-4000-8000-000000000001',current_setting('test.expired_calendar')::uuid,
 current_setting('test.today')::date)->>'calendar_version_id',NULL,
 'resuming a calendar does not silently fill the expired-to-resumed gap');
SELECT is(public.leave_calendar_day('cf920000-0000-4000-8000-000000000001',current_setting('test.expired_calendar')::uuid,
 current_setting('test.today')::date+7)->>'holiday','Resumed holiday',
 'resumed effective version applies only from its configured future date');

-- A revision that breaks an explicit year period rolls back all boundary changes.
SELECT set_config('test.coverage_calendar',public.leave_create_calendar(
 'cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000002',
 'coverage','Coverage guard calendar',current_setting('test.today')::date-5,NULL,ARRAY[5,6]::smallint[],'[]'::jsonb,
 'Coverage source','Coverage guard original')::text,true);
SELECT public.leave_create_year_period('cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000002',
 current_setting('test.coverage_calendar')::uuid,current_setting('test.today')::date,current_setting('test.today')::date+20,
 'Coverage period','Existing configured year must remain covered');
SELECT throws_ok(format($q$SELECT public.leave_revise_calendar(
 'cf920000-0000-4000-8000-000000000001','%s',(current_setting('test.today')::date+10),
 (current_setting('test.today')::date+12),ARRAY[0,1]::smallint[],'[]'::jsonb,
 'Coverage gap','Rejected because configured year would be uncovered')$q$,
 current_setting('test.coverage_calendar')),'22023','leave_calendar_revision_breaks_year_period',
 'year-period coverage blocks a revision that creates an uncovered interval');
SELECT is(public.leave_calendar_day('cf920000-0000-4000-8000-000000000001',current_setting('test.coverage_calendar')::uuid,
 current_setting('test.today')::date+15)->>'effective_until',NULL,
 'failed coverage check rolls back the old calendar boundary update');

-- Type versions use the same prospective insertion semantics and preserve the scheduled snapshot.
SELECT set_config('test.leave_type',public.leave_create_type(
 'cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001',
 'recovery-type','Recovery type',current_setting('test.today')::date-5,'paid','tracked',true,
 'Type source','Initial type snapshot','working_days')::text,true);
SELECT set_config('test.type_scheduled',public.leave_revise_type(
 'cf920000-0000-4000-8000-000000000001',current_setting('test.leave_type')::uuid,
 current_setting('test.today')::date+30,'unpaid','tracked','working_days',true,
 'Planned type','Future type version scheduled first')::text,true);
SELECT lives_ok(format($q$SELECT public.leave_revise_type(
 'cf920000-0000-4000-8000-000000000001','%s',(current_setting('test.today')::date+10),
 'paid','untracked','calendar_days',false,'Urgent type','Prospective version before scheduled type')$q$,
 current_setting('test.leave_type')),
 'urgent type revision can be inserted before a later scheduled type version');
SELECT set_config('test.type_versions',(
 SELECT t->'versions' FROM jsonb_array_elements(public.leave_configuration_snapshot(
  'cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001')->'types') t
 WHERE t->>'id'=current_setting('test.leave_type'))::text,true);
SELECT set_config('test.type_urgent',(
 SELECT v->>'id' FROM jsonb_array_elements(current_setting('test.type_versions')::jsonb) v WHERE v->>'version'='3'),true);
SELECT is((SELECT v->>'version' FROM jsonb_array_elements(current_setting('test.type_versions')::jsonb) v WHERE v->>'id'=current_setting('test.type_urgent')),'3',
 'inserted type snapshot uses max version plus one');
SELECT is((SELECT v->>'effective_until' FROM jsonb_array_elements(current_setting('test.type_versions')::jsonb) v WHERE v->>'id'=current_setting('test.type_urgent')),
 (current_setting('test.today')::date+30)::text,'inserted type version ends at the next scheduled boundary');
SELECT is((SELECT (v->>'balance_mode')||':'||(v->>'day_count_basis')||':'||(v->>'half_day_allowed')
 FROM jsonb_array_elements(current_setting('test.type_versions')::jsonb) v WHERE v->>'id'=current_setting('test.type_urgent')),
 'untracked:calendar_days:false','inserted type version preserves all independent configured policy dimensions');
SELECT is((SELECT v->>'balance_mode' FROM jsonb_array_elements(current_setting('test.type_versions')::jsonb) v WHERE v->>'id'=current_setting('test.type_scheduled')),
 'tracked','later scheduled type snapshot retains its original content');
SELECT throws_ok(format($q$SELECT public.leave_revise_type(
 'cf920000-0000-4000-8000-000000000001','%s',(current_setting('test.today')::date+30),
 'paid','tracked','working_days',true,'Same start','Do not replace a scheduled type implicitly')$q$,
 current_setting('test.leave_type')),'23P01','leave_type_revision_invalid',
 'same-start replacement of a planned type version remains an explicit conflict');
SELECT is(jsonb_array_length((SELECT t->'versions' FROM jsonb_array_elements(public.leave_configuration_snapshot(
 'cf920000-0000-4000-8000-000000000001','cf950000-0000-4000-8000-000000000001')->'types') t
 WHERE t->>'id'=current_setting('test.leave_type'))),3,
 'rejected same-start type replacement leaves the accepted version history unchanged');

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
