begin;

create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '40000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'creator-admin@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Creator Admin"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '40000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'applicant@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Creator Applicant"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '40000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'other-creator@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Other Creator"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  );

update public.user_roles
set revoked_at = clock_timestamp(),
    revoked_by = '40000000-0000-0000-0000-000000000001'
where user_id in (
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000003'
) and revoked_at is null;
insert into public.user_roles (user_id, role, granted_by)
values
  (
    '40000000-0000-0000-0000-000000000001', 'admin',
    '40000000-0000-0000-0000-000000000001'
  ),
  (
    '40000000-0000-0000-0000-000000000003', 'influencer',
    '40000000-0000-0000-0000-000000000001'
  );

insert into storage.objects (bucket_id, name, owner)
values (
  'restaurant-images',
  '40000000-0000-0000-0000-000000000002/secure-kitchen.jpg',
  '40000000-0000-0000-0000-000000000002'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"40000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;

select throws_ok(
  $$insert into public.influencer_applications (user_id)
    values (auth.uid())$$,
  '42501', null,
  'tourist cannot insert an application outside the RPC'
);
select lives_ok(
  $$select public.save_influencer_application_draft(
    null, 'Creator Applicant', 'instagram',
    'https://instagram.com/creator-applicant', 1200, 'Local food',
    'I publish careful and useful local food recommendations.', true, null
  )$$,
  'tourist saves a complete creator draft through the RPC'
);
select lives_ok(
  $$select public.submit_influencer_application(
    (select id from public.influencer_applications where user_id = auth.uid()), 1
  )$$,
  'tourist submits their creator application'
);
select throws_ok(
  $$update public.user_roles set role = 'admin' where user_id = auth.uid()$$,
  '42501', null,
  'applicant cannot grant a role directly'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"40000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select lives_ok(
  $$select public.admin_decide_influencer_application(
    (select id from public.influencer_applications
      where user_id = '40000000-0000-0000-0000-000000000002'),
    'approved', 'Profile and public work meet the creator rules.', 2
  )$$,
  'admin approval atomically grants creator access'
);
select is(
  (
    select role::text
    from public.user_roles
    where user_id = '40000000-0000-0000-0000-000000000002'
      and revoked_at is null
  ),
  'influencer',
  'approved applicant receives the influencer role'
);
select throws_ok(
  $$select public.admin_decide_influencer_application(
    (select id from public.influencer_applications
      where user_id = '40000000-0000-0000-0000-000000000002'),
    'rejected', 'Conflicting stale decision.', 2
  )$$,
  'P0002', 'Application is not awaiting review',
  'a completed application cannot receive a conflicting decision'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"40000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;

select throws_ok(
  $sql$select public.create_restaurant_draft(
    'Secure Kitchen', '1 Restaurant Test Road', 'Penang', 'George Town',
    'Malay', '$$', 'Nasi lemak', 'https://example.com/deceptive',
    null, null, null
  )$sql$,
  '22023', 'Unsupported social URL',
  'restaurant RPC rejects unsupported social hosts'
);
select lives_ok(
  $sql$select public.create_restaurant_draft(
    'Secure Kitchen', '1 Restaurant Test Road', 'Penang', 'George Town',
    'Malay', '$$', 'Nasi lemak',
    'https://www.tiktok.com/@secure/video/123',
    '40000000-0000-0000-0000-000000000002/secure-kitchen.jpg',
    null, null
  )$sql$,
  'approved creator creates a restaurant draft'
);
select lives_ok(
  $$select public.submit_restaurant_revision(
    (select current_revision_id from public.restaurants where owner_id = auth.uid()),
    null
  )$$,
  'creator submits the restaurant draft for moderation'
);
select throws_ok(
  $$insert into public.discount_codes (
    restaurant_id, owner_id, code, description, redemption_terms,
    starts_at, expires_at
  ) values (
    (select id from public.restaurants where owner_id = auth.uid()),
    auth.uid(), 'BYPASS', 'Unsafe direct insert', 'Not permitted',
    clock_timestamp(), clock_timestamp() + interval '1 day'
  )$$,
  '42501', null,
  'creator cannot bypass discount transitions with direct inserts'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"40000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select lives_ok(
  $$select public.admin_moderate_restaurant_revision(
    (select id from public.restaurant_revisions where status = 'submitted'),
    'approved', 'Public business details and creator post verified.', 1
  )$$,
  'admin approves a restaurant using its expected version'
);
select throws_ok(
  $$select public.admin_moderate_restaurant_revision(
    (select id from public.restaurant_revisions where status = 'approved'),
    'rejected', 'Conflicting stale decision.', 1
  )$$,
  '40001', 'Restaurant changed concurrently',
  'approved restaurant cannot receive a second conflicting decision'
);

reset role;
set local role anon;
select is(
  (select count(*) from public.published_restaurants),
  1::bigint,
  'anonymous guest can browse the approved restaurant projection'
);
select throws_ok(
  $$select count(*) from public.restaurant_revisions$$,
  '42501', null,
  'anonymous guest cannot read private restaurant revisions'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"40000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;

select lives_ok(
  $$select public.create_discount_draft(
    (select id from public.restaurants where owner_id = auth.uid()),
    'LOCAL10', 'Ten percent off selected items',
    'Show the code before ordering. Exclusions may apply.',
    clock_timestamp() - interval '1 minute',
    clock_timestamp() + interval '1 day'
  )$$,
  'owner creates a bounded discount draft for an approved listing'
);
select lives_ok(
  $$select public.transition_discount(
    (select id from public.discount_codes where owner_id = auth.uid()),
    'publish', 1
  )$$,
  'owner publishes the discount through a state transition'
);
select is(
  jsonb_array_length(public.list_active_discounts(null)),
  1,
  'server-time active discount appears in the public read function'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"40000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*) from public.restaurants),
  0::bigint,
  'another creator cannot read a private restaurant entity they do not own'
);
select throws_ok(
  $$select public.create_discount_draft(
    (select id from public.published_restaurants limit 1),
    'THEFT10', 'Unauthorized offer', 'Should never be accepted',
    clock_timestamp(), clock_timestamp() + interval '1 day'
  )$$,
  '42501', 'Approved owned restaurant required',
  'another creator cannot create a discount for the listing'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"40000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.admin_set_account_access(
    '40000000-0000-0000-0000-000000000002', 'restricted',
    'Creator access is temporarily restricted.', 'Automated RLS test',
    clock_timestamp() + interval '1 day', 1
  )$$,
  'admin restriction is applied through the audited account RPC'
);

reset role;
set local role anon;
select is(
  jsonb_array_length(public.list_active_discounts(null)),
  0,
  'restriction immediately hides the creator active discount'
);

select * from finish();
rollback;
