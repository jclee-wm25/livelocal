begin;

create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '50000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'save-owner@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Save Owner"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '50000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'other-saver@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Other Saver"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '50000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'save-admin@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Save Admin"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  );

update public.user_roles
set revoked_at = clock_timestamp(),
    revoked_by = '50000000-0000-0000-0000-000000000003'
where user_id = '50000000-0000-0000-0000-000000000003'
  and revoked_at is null;
insert into public.user_roles (user_id, role, granted_by)
values (
  '50000000-0000-0000-0000-000000000003', 'admin',
  '50000000-0000-0000-0000-000000000003'
);

insert into public.spots (id, owner_id)
values (
  '51000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001'
);
insert into public.spot_revisions (
  id, spot_id, revision_number, author_id, status, name, category,
  description, state, city, address, price_range, best_time, things_to_do,
  latitude, longitude, submitted_at, decided_at
)
values (
  '52000000-0000-0000-0000-000000000001',
  '51000000-0000-0000-0000-000000000001', 1,
  '50000000-0000-0000-0000-000000000001', 'approved',
  'Saved Test Park', 'Park',
  'A complete public spot used to verify saved-place permissions.',
  'Penang', 'George Town', '1 Saved Place Road', '$', 'Morning',
  'Walk through the public garden', 5.4141, 100.3288,
  clock_timestamp(), clock_timestamp()
);
update public.spots set
  current_revision_id = '52000000-0000-0000-0000-000000000001',
  approved_revision_id = '52000000-0000-0000-0000-000000000001'
where id = '51000000-0000-0000-0000-000000000001';
insert into public.published_spots (
  id, revision_id, name, category, description, state, city, address,
  price_range, best_time, things_to_do, latitude, longitude
)
values (
  '51000000-0000-0000-0000-000000000001',
  '52000000-0000-0000-0000-000000000001',
  'Saved Test Park', 'Park',
  'A complete public spot used to verify saved-place permissions.',
  'Penang', 'George Town', '1 Saved Place Road', '$', 'Morning',
  'Walk through the public garden', 5.4141, 100.3288
);

set local role anon;
select throws_ok(
  $$select count(*) from public.saved_places$$,
  '42501', null,
  'anonymous users cannot read private saves'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"50000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.set_saved_place(
    'spot', '51000000-0000-0000-0000-000000000001', true
  )$$,
  'authenticated user saves an approved public target through the RPC'
);
select is(
  (select count(*) from public.saved_places),
  1::bigint,
  'owner reads their saved place'
);
select lives_ok(
  $$select public.set_saved_place(
    'spot', '51000000-0000-0000-0000-000000000001', true
  )$$,
  'repeating save is idempotent'
);
select is(
  (select count(*) from public.saved_places),
  1::bigint,
  'duplicate save is prevented by the database'
);
select throws_ok(
  $$insert into public.saved_places (user_id, spot_id)
    values (auth.uid(), '51000000-0000-0000-0000-000000000001')$$,
  '42501', null,
  'client cannot bypass the saved-place RPC'
);
select lives_ok(
  $$select public.update_my_discovery_location(
    'manual', 'Penang', 'George Town', 5.4141, 100.3288, null
  )$$,
  'user stores an explicit manual location preference'
);
select lives_ok(
  $$select public.create_itinerary_from_saved(
    'George Town day', 'George Town, Penang', 5.4141, 100.3288,
    '[{"type":"spot","id":"51000000-0000-0000-0000-000000000001"}]'::jsonb
  )$$,
  'user creates an itinerary only from their saved public targets'
);
select is(
  (select count(*) from public.itinerary_items),
  1::bigint,
  'itinerary order is persisted as server-owned item rows'
);
select throws_ok(
  $$select public.replace_itinerary_order(
    (select id from public.itineraries limit 1),
    '[{"type":"spot","id":"51000000-0000-0000-0000-000000000001"}]'::jsonb,
    99
  )$$,
  '40001', 'Itinerary changed concurrently',
  'stale itinerary version is rejected'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"50000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*) from public.saved_places),
  0::bigint,
  'another user cannot read the owner saved places'
);
select throws_ok(
  $$select public.create_itinerary_from_saved(
    'Stolen route', 'George Town, Penang', 5.4141, 100.3288,
    '[{"type":"spot","id":"51000000-0000-0000-0000-000000000001"}]'::jsonb
  )$$,
  '42501', 'Itinerary contains an unavailable or unsaved target',
  'another user cannot build an itinerary from someone else saved target'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"50000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.admin_set_account_access(
    '50000000-0000-0000-0000-000000000001', 'restricted',
    'Saved-place access is temporarily restricted.', 'RLS verification',
    clock_timestamp() + interval '1 day', 1
  )$$,
  'admin restricts the account through the audited RPC'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"50000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$select public.set_saved_place(
    'spot', '51000000-0000-0000-0000-000000000001', false
  )$$,
  '42501', 'Account cannot manage saved places',
  'restricted account cannot mutate saved places'
);

select * from finish();
rollback;
