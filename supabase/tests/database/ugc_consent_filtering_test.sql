begin;

select plan(16);

-- Setup standard roles
set local search_path = public, auth;

-- Create test user
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000001'::uuid, 'test@example.com');
insert into public.profiles (id, display_name) values ('00000000-0000-0000-0000-000000000001'::uuid, 'Test User');

-- Set app_settings with test version and test banned word
insert into public.app_settings (key, value)
values 
  ('current_ugc_rule_version', '"test-v1"'::jsonb),
  ('banned_words', '["badword", "nasty"]'::jsonb)
on conflict (key) do update set value = excluded.value;

-- Test: unauthenticated acceptance rejected
set role anon;
select throws_matching(
  $$ select public.accept_current_ugc_rules() $$,
  'Authentication required',
  'accept_current_ugc_rules requires authentication'
);

-- Test: authenticated user can accept rules
set role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}', true);

select lives_ok(
  $$ select public.accept_current_ugc_rules() $$,
  'Authenticated user can accept current UGC rules'
);

-- Test: Idempotent acceptance
select lives_ok(
  $$ select public.accept_current_ugc_rules() $$,
  'Accepting rules multiple times is idempotent'
);

-- Test: Acceptance verified
select results_eq(
  $$ select rule_version from public.user_ugc_rule_acceptances where user_id = '00000000-0000-0000-0000-000000000001'::uuid $$,
  $$ values ('test-v1') $$,
  'User acceptance is correctly recorded for current version'
);

-- Test: Historical acceptance preservation & stale acceptance rejection
-- We simulate a version change
set role postgres;
update public.app_settings set value = '"test-v2"'::jsonb where key = 'current_ugc_rule_version';
set role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}', true);

select throws_matching(
  $$ select private.assert_current_ugc_rules_accepted() $$,
  'UGC_RULES_ACCEPTANCE_REQUIRED',
  'assert_current_ugc_rules_accepted fails after current version changes'
);

-- Re-accept new version
select public.accept_current_ugc_rules();

select results_eq(
  $$ select rule_version from public.user_ugc_rule_acceptances where user_id = '00000000-0000-0000-0000-000000000001'::uuid order by rule_version $$,
  $$ values ('test-v1'), ('test-v2') $$,
  'Historical acceptance is preserved alongside new acceptance'
);

-- Test: upsert_review rejects without current acceptance
-- Set to a new user
set role postgres;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000002'::uuid, 'test2@example.com');
insert into public.profiles (id, display_name) values ('00000000-0000-0000-0000-000000000002'::uuid, 'Test User 2');
insert into public.spots (id, owner_id, status) values ('00000000-0000-0000-0000-000000000010'::uuid, '00000000-0000-0000-0000-000000000002'::uuid, 'published');
insert into public.published_spots (id, name, city, state) values ('00000000-0000-0000-0000-000000000010'::uuid, 'Test', 'Test', 'Test');
set role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000002", "role": "authenticated"}', true);

select throws_matching(
  $$ select public.upsert_review('spot', '00000000-0000-0000-0000-000000000010'::uuid, 5, 'Great spot!') $$,
  'UGC_RULES_ACCEPTANCE_REQUIRED',
  'upsert_review throws UGC_RULES_ACCEPTANCE_REQUIRED if rules not accepted'
);

-- Test: submit_spot_revision rejects without current acceptance
set role postgres;
insert into public.spot_revisions (id, spot_id, revision_number, author_id, status, name, category, description, state, city, address, price_range, best_time, things_to_do)
values ('00000000-0000-0000-0000-000000000011'::uuid, '00000000-0000-0000-0000-000000000010'::uuid, 1, '00000000-0000-0000-0000-000000000002'::uuid, 'draft', 'Test', 'Test', 'A great description of the test place', 'Test', 'Test', 'Test', '$', 'Test', 'Test');
set role authenticated;
select set_config('request.jwt.claims', '{"sub": "00000000-0000-0000-0000-000000000002", "role": "authenticated"}', true);

select throws_matching(
  $$ select public.submit_spot_revision('00000000-0000-0000-0000-000000000011'::uuid) $$,
  'UGC_RULES_ACCEPTANCE_REQUIRED',
  'submit_spot_revision throws UGC_RULES_ACCEPTANCE_REQUIRED if rules not accepted'
);


-- Test: upsert_review succeeds after acceptance (if content clean)
select public.accept_current_ugc_rules();

select lives_ok(
  $$ select public.upsert_review('spot', '00000000-0000-0000-0000-000000000010'::uuid, 5, 'Great spot!') $$,
  'upsert_review succeeds after rules are accepted'
);

-- Test: Filtering blocklist - whole word match rejects
select throws_matching(
  $$ select public.upsert_review('spot', '00000000-0000-0000-0000-000000000010'::uuid, 5, 'This is a badword.') $$,
  'UGC_CONTENT_RESTRICTED',
  'Filtering rejects whole word match with punctuation'
);

-- Test: Filtering blocklist - whole word match case insensitive
select throws_matching(
  $$ select public.upsert_review('spot', '00000000-0000-0000-0000-000000000010'::uuid, 5, 'This is a BADWORD ') $$,
  'UGC_CONTENT_RESTRICTED',
  'Filtering rejects case insensitive match'
);

-- Test: Filtering blocklist - substring match succeeds
select lives_ok(
  $$ select public.upsert_review('spot', '00000000-0000-0000-0000-000000000010'::uuid, 5, 'This is notbadwordy!') $$,
  'Filtering ignores substring matches to avoid false positives'
);

-- Test: filtering applied to submit_spot_revision
set role postgres;
update public.spot_revisions set name = 'This is a badword', image_path = 'test.jpg', image_rights_confirmed_at = clock_timestamp() where id = '00000000-0000-0000-0000-000000000011'::uuid;
update public.spots set current_revision_id = '00000000-0000-0000-0000-000000000011'::uuid where id = '00000000-0000-0000-0000-000000000010'::uuid;
set role authenticated;
select throws_matching(
  $$ select public.submit_spot_revision('00000000-0000-0000-0000-000000000011'::uuid) $$,
  'UGC_CONTENT_RESTRICTED',
  'submit_spot_revision rejects if name contains a banned word'
);

-- Test: Client cannot directly insert into acceptance table
select throws_matching(
  $$ insert into public.user_ugc_rule_acceptances (user_id, rule_version) values ('00000000-0000-0000-0000-000000000002'::uuid, 'test-v2') $$,
  'permission denied for table user_ugc_rule_acceptances',
  'Authenticated users cannot directly insert into acceptance table'
);

-- Test: Client cannot directly update app_settings
select throws_matching(
  $$ update public.app_settings set value = '"bypassed"'::jsonb where key = 'current_ugc_rule_version' $$,
  'permission denied for table app_settings',
  'Authenticated users cannot modify app_settings'
);

select * from finish();
rollback;
