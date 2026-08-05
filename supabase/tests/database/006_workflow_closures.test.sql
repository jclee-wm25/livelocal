begin;

create extension if not exists pgtap with schema extensions;
select plan(34);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '70000000-0000-0000-0000-000000000001', 'authenticated',
    'authenticated', 'closure-admin@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Closure Admin"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '70000000-0000-0000-0000-000000000002', 'authenticated',
    'authenticated', 'closure-creator@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Closure Creator"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '70000000-0000-0000-0000-000000000003', 'authenticated',
    'authenticated', 'closure-tourist@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Closure Tourist"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  );

update public.user_roles set revoked_at = clock_timestamp(),
  revoked_by = '70000000-0000-0000-0000-000000000001'
where user_id in (
  '70000000-0000-0000-0000-000000000001',
  '70000000-0000-0000-0000-000000000002'
) and revoked_at is null;
insert into public.user_roles (user_id, role, granted_by)
values
  (
    '70000000-0000-0000-0000-000000000001', 'admin',
    '70000000-0000-0000-0000-000000000001'
  ),
  (
    '70000000-0000-0000-0000-000000000002', 'influencer',
    '70000000-0000-0000-0000-000000000001'
  );

select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$select public.admin_save_guide_draft(
    null, 'Tourist guide', 'Brickfields', 'Kuala Lumpur',
    'An unauthorized but otherwise complete guide route overview.',
    '["Start"]'::jsonb, '["Walk to start"]'::jsonb, '1 hour', null
  )$$,
  '42501', 'Admin permission required',
  'tourist cannot curate guides'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.admin_save_guide_draft(
    null, 'Brickfields morning route', 'Brickfields', 'Kuala Lumpur',
    'A verified public route through food and heritage locations.',
    '["Breakfast","Heritage street"]'::jsonb,
    '["Start at breakfast","Continue to heritage street"]'::jsonb,
    '2 hours', null
  )$$,
  'admin creates a guide draft'
);
select lives_ok(
  $$select public.admin_publish_guide_revision(
    (select current_revision_id from public.guides limit 1),
    'Initial route verified.', 1
  )$$,
  'admin publishes the initial guide revision'
);
select lives_ok(
  $$select public.admin_save_guide_draft(
    (select id from public.guides limit 1),
    'Brickfields morning route updated', 'Brickfields', 'Kuala Lumpur',
    'A revised public route through accessible food and heritage locations.',
    '["Breakfast","Accessible heritage street"]'::jsonb,
    '["Start at breakfast","Continue along the accessible path"]'::jsonb,
    '2 hours', 2
  )$$,
  'admin creates a revision without replacing the public projection'
);
select lives_ok(
  $$select public.admin_publish_guide_revision(
    (select current_revision_id from public.guides limit 1),
    'Revised accessibility details verified.', 3
  )$$,
  'admin publishes the revised guide'
);
select throws_ok(
  $$select public.admin_archive_guide(
    (select id from public.guides limit 1), 'Stale archive attempt.', 3
  )$$,
  '40001', 'Guide changed concurrently',
  'stale guide archive is rejected'
);
select lives_ok(
  $$select public.admin_archive_guide(
    (select id from public.guides limit 1), 'Route is no longer current.', 4
  )$$,
  'admin archives a current guide with a reason'
);

reset role;
set local role anon;
select is(
  (select count(*) from public.published_guides), 0::bigint,
  'archived guide is no longer public'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.create_restaurant_draft(
    'Closure Test Kitchen', '12 Test Street', 'Penang', 'George Town',
    'Malaysian', '$$', 'Noodles and coffee',
    'https://www.instagram.com/closuretest', null, 5.4141, 100.3288
  )$$,
  'creator creates a restaurant draft'
);
select lives_ok(
  $$select public.submit_restaurant_revision(
    (select current_revision_id from public.restaurants
      where owner_id = auth.uid()), null
  )$$,
  'creator submits the restaurant'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.admin_moderate_restaurant_revision(
    (select current_revision_id from public.restaurants
      where owner_id = '70000000-0000-0000-0000-000000000002'),
    'approved', 'Business and supporting post verified.', 1
  )$$,
  'admin publishes the restaurant'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.create_discount_draft(
    (select id from public.restaurants where owner_id = auth.uid()),
    'CLOSURE10', 'Ten percent off selected dishes.',
    'Show the code before ordering. Business terms apply.',
    clock_timestamp() - interval '1 hour',
    clock_timestamp() + interval '30 days'
  )$$,
  'creator creates a discount draft for their approved restaurant'
);
select lives_ok(
  $$select public.transition_discount(
    (select id from public.discount_codes where owner_id = auth.uid()),
    'publish', 1
  )$$,
  'creator activates the discount'
);
select is(
  jsonb_array_length(public.list_my_discounts()), 1,
  'creator lists their own active and inactive discounts'
);
select lives_ok(
  $$select public.transition_discount(
    (select id from public.discount_codes where owner_id = auth.uid()),
    'pause', 2
  )$$,
  'creator pauses an active discount'
);
select throws_ok(
  $$select public.transition_discount(
    (select id from public.discount_codes where owner_id = auth.uid()),
    'resume', 2
  )$$,
  '40001', 'Discount changed concurrently',
  'stale discount transition is rejected'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$select public.list_my_discounts()$$,
  '42501', 'Approved creator role required',
  'tourist cannot list creator discount management data'
);
select lives_ok(
  $$select public.report_content(
    'restaurant', (select id from public.published_restaurants),
    'broken_link', 'The Instagram page returns not found.', false
  )$$,
  'tourist submits a pending broken-link moderation case'
);
select throws_ok(
  $$select public.report_content(
    'restaurant', (select id from public.published_restaurants),
    'broken_link', 'Duplicate report.', false
  )$$,
  '23505', null,
  'duplicate active report is rejected'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  jsonb_array_length(public.admin_list_moderation_cases()), 1,
  'admin sees the restaurant report with a public preview'
);
select lives_ok(
  $$select public.admin_decide_content_report(
    (select id from public.moderation_cases where reason = 'broken_link'),
    'upheld', 'The external page is confirmed unavailable.', 1
  )$$,
  'admin upholds the broken-link report'
);
select is(
  (select social_link_status from public.published_restaurants), 'removed',
  'upheld link report removes only the external link'
);
select is(
  (select count(*) from public.audit_events
    where action = 'admin.content_report_upheld'), 1::bigint,
  'content moderation decision is audited'
);
select lives_ok(
  $$select public.admin_set_account_access(
    '70000000-0000-0000-0000-000000000003', 'restricted',
    'Temporary restriction for appeal testing.',
    'Test evidence requires a temporary restriction.',
    clock_timestamp() + interval '7 days', 1
  )$$,
  'admin restricts the tourist with an auditable decision'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.submit_account_appeal(
    (select id from public.account_access_decisions
      where user_id = auth.uid() order by created_at desc limit 1),
    'context', 'Additional context should be reviewed.'
  )$$,
  'restricted tourist submits an appeal'
);
select throws_ok(
  $$select public.submit_account_appeal(
    (select id from public.account_access_decisions
      where user_id = auth.uid() order by created_at desc limit 1),
    'context', 'Duplicate active appeal.'
  )$$,
  '23505', null,
  'duplicate active appeal is rejected'
);
select is(
  (select count(*) from public.account_appeals), 1::bigint,
  'restricted user can reload their own appeal status'
);
select throws_ok(
  $$select public.admin_list_account_appeals()$$,
  '42501', 'Admin permission required',
  'tourist cannot read the admin appeal queue'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  jsonb_array_length(public.admin_list_account_appeals()), 1,
  'admin sees the pending appeal'
);
select lives_ok(
  $$select public.admin_decide_account_appeal(
    (select id from public.account_appeals), 'upheld',
    'The additional evidence resolves the restriction.', 1
  )$$,
  'admin accepts the appeal with an expected version'
);
select is(
  (select status::text from public.account_access
    where user_id = '70000000-0000-0000-0000-000000000003'),
  'active',
  'accepted appeal restores account access transactionally'
);
select is(
  (select count(*) from public.notifications
    where user_id = '70000000-0000-0000-0000-000000000003'
      and type = 'account_appeal_upheld'),
  1::bigint,
  'appeal outcome creates an in-app notification'
);
select throws_ok(
  $$select public.admin_decide_account_appeal(
    (select id from public.account_appeals), 'dismissed',
    'Conflicting second decision.', 1
  )$$,
  'P0002', 'Active appeal not found',
  'a decided appeal cannot receive a conflicting second decision'
);

reset role;
set local role anon;
select throws_ok(
  $$select public.report_content(
    'restaurant', (select id from public.published_restaurants),
    'broken_link', 'Anonymous report.', false
  )$$,
  '42501', 'Account cannot report content',
  'anonymous users cannot submit reports'
);

select * from finish();
rollback;
