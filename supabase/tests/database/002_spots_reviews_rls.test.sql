begin;

create extension if not exists pgtap with schema extensions;
select plan(18);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '30000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'admin-three@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Admin Three"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '30000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'author@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Review Author"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '30000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'reporter@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Case Reporter"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  );

update public.user_roles
set revoked_at = clock_timestamp(),
    revoked_by = '30000000-0000-0000-0000-000000000001'
where user_id = '30000000-0000-0000-0000-000000000001'
  and revoked_at is null;
insert into public.user_roles (user_id, role, granted_by)
values (
  '30000000-0000-0000-0000-000000000001', 'admin',
  '30000000-0000-0000-0000-000000000001'
);

insert into storage.objects (bucket_id, name, owner)
values (
  'spot-images',
  '30000000-0000-0000-0000-000000000002/rls-test.jpg',
  '30000000-0000-0000-0000-000000000002'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"30000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;

select throws_ok(
  $$insert into public.spots (owner_id) values (auth.uid())$$,
  '42501', null,
  'authenticated user cannot insert a spot directly'
);
select lives_ok(
  $$select public.create_spot_draft(
    'RLS Test Garden', 'Park / Walkway',
    'A detailed local garden description for database testing.',
    'Penang', 'George Town', '1 Secure Test Road', '$',
    'Morning', 'Walk around the garden',
    '30000000-0000-0000-0000-000000000002/rls-test.jpg', null, null
  )$$,
  'authenticated user creates a draft through RPC'
);
select is(
  (select count(*) from public.spots where owner_id = auth.uid()),
  1::bigint,
  'owner can read own private spot entity'
);
select public.accept_current_ugc_rules();
select throws_ok(
  $$select public.submit_spot_revision(
    (select current_revision_id from public.spots where owner_id = auth.uid()),
    null
  )$$,
  '22023', 'Spot image and rights confirmation are required',
  'owner cannot submit without image rights confirmation'
);
select lives_ok(
  $$select public.confirm_spot_image_rights(
    (select current_revision_id from public.spots where owner_id = auth.uid())
  )$$,
  'owner confirms rights for the current draft image'
);
select lives_ok(
  $$select public.submit_spot_revision(
    (select current_revision_id from public.spots where owner_id = auth.uid()),
    null
  )$$,
  'owner submits current draft through RPC'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"30000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select lives_ok(
  $$select public.admin_moderate_spot_revision(
    (select id from public.spot_revisions where status = 'submitted' limit 1),
    'approved', 'Verified test listing', 1
  )$$,
  'admin approves with expected version'
);
select throws_ok(
  $$select public.admin_moderate_spot_revision(
    (select id from public.spot_revisions where status = 'approved' limit 1),
    'rejected', 'Stale decision', 1
  )$$,
  '40001', 'Spot changed concurrently',
  'stale spot moderation is rejected'
);

reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select is(
  (select count(*) from public.published_spots),
  1::bigint,
  'anonymous guest can read approved spot projection'
);
select throws_ok(
  $$select count(*) from public.spot_revisions$$,
  '42501', null,
  'anonymous guest has no access to private revisions'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"30000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select public.accept_current_ugc_rules();
select lives_ok(
  $$select public.upsert_review(
    'spot', (select id from public.published_spots limit 1), 4,
    'A useful and specific review.', null
  )$$,
  'authenticated user creates one review through RPC'
);
select is(
  (select review_count from public.published_spots limit 1),
  1,
  'review aggregate count updates transactionally'
);
select lives_ok(
  $$select public.upsert_review(
    'spot', (select id from public.published_spots limit 1), 5,
    'An updated and still useful review.', 1
  )$$,
  'same user edits the existing review'
);
select is(
  (select count(*) from public.reviews where user_id = auth.uid()),
  1::bigint,
  'editing does not create a second active review'
);
select is(
  (select count(*) from public.review_edit_history),
  1::bigint,
  'review edit history preserves prior content'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"30000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.report_content(
    'review', (select id from public.public_reviews limit 1),
    'misleading', 'The description conflicts with the listing.', true
  )$$,
  'report creates a pending case and personal hide'
);
select is(
  (select count(*) from public.public_reviews),
  0::bigint,
  'reported review is hidden only for its reporter'
);

reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select is(
  (select count(*) from public.public_reviews),
  1::bigint,
  'one report does not globally hide the review'
);

select * from finish();
rollback;
