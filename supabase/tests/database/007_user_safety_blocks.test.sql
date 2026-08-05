begin;

create extension if not exists pgtap with schema extensions;
select plan(17);

select has_table('public', 'user_blocks', 'user block table exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.user_blocks'::regclass),
  'user blocks have RLS enabled'
);
select has_function(
  'public', 'block_content_author', array['text', 'uuid'],
  'content-author block RPC exists'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '80000000-0000-0000-0000-000000000001', 'authenticated',
    'authenticated', 'safety-author@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Safety Author"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '80000000-0000-0000-0000-000000000002', 'authenticated',
    'authenticated', 'safety-viewer@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Safety Viewer"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '80000000-0000-0000-0000-000000000003', 'authenticated',
    'authenticated', 'safety-other@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Safety Other"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  );

insert into public.spots (id, owner_id)
values (
  '81000000-0000-0000-0000-000000000001',
  '80000000-0000-0000-0000-000000000001'
);
insert into public.spot_revisions (
  id, spot_id, revision_number, author_id, status, name, category,
  description, state, city, address, price_range, best_time, things_to_do,
  submitted_at, decided_at
)
values (
  '82000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001', 1,
  '80000000-0000-0000-0000-000000000001', 'approved',
  'Safety Test Spot', 'Culture',
  'A complete public description used to verify author block filtering.',
  'Penang', 'George Town', '1 Safety Test Road', '$$',
  'Morning', 'Explore the public location', clock_timestamp(), clock_timestamp()
);
update public.spots set
  current_revision_id = '82000000-0000-0000-0000-000000000001',
  approved_revision_id = '82000000-0000-0000-0000-000000000001'
where id = '81000000-0000-0000-0000-000000000001';
insert into public.published_spots (
  id, revision_id, name, category, description, state, city, address,
  price_range, best_time, things_to_do
)
select spot_id, id, name, category, description, state, city, address,
  price_range, best_time, things_to_do
from public.spot_revisions
where id = '82000000-0000-0000-0000-000000000001';

insert into public.reviews (
  id, user_id, target_type, target_id, rating, body, author_display_name
)
values (
  '83000000-0000-0000-0000-000000000001',
  '80000000-0000-0000-0000-000000000001', 'spot',
  '81000000-0000-0000-0000-000000000001', 4,
  'A useful but blockable public review.', 'Safety Author'
);
insert into public.public_reviews (
  id, target_type, target_id, rating, body, author_display_name,
  version, created_at, updated_at
)
select id, target_type, target_id, rating, body, author_display_name,
  version, created_at, updated_at
from public.reviews
where id = '83000000-0000-0000-0000-000000000001';

set local role anon;
select is((select count(*) from public.public_reviews), 1::bigint,
  'guest sees the public review');
select is((select count(*) from public.published_spots), 1::bigint,
  'guest sees the public spot');

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"80000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.block_content_author(
    'review', '83000000-0000-0000-0000-000000000001'
  )$$,
  'viewer blocks an author by public content ID'
);
select is((select count(*) from public.user_blocks), 1::bigint,
  'viewer can inspect their private block relationship');
select is((select count(*) from public.public_reviews), 0::bigint,
  'blocked author review is filtered for viewer');
select is((select count(*) from public.published_spots), 0::bigint,
  'blocked author spot is filtered for viewer');
select lives_ok(
  $$select public.block_content_author(
    'spot', '81000000-0000-0000-0000-000000000001'
  )$$,
  'repeated block is idempotent'
);
select throws_ok(
  $$insert into public.user_blocks (blocker_id, blocked_user_id)
    values (auth.uid(), '80000000-0000-0000-0000-000000000003')$$,
  '42501', null,
  'client cannot create an arbitrary user block directly'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"80000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$select public.block_content_author(
    'review', '83000000-0000-0000-0000-000000000001'
  )$$,
  '22023', 'Users cannot block themselves',
  'author cannot block themselves'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"80000000-0000-0000-0000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select is((select count(*) from public.user_blocks), 0::bigint,
  'another user cannot see private block relationships');

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"80000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select is(jsonb_array_length(public.list_my_blocked_users()), 1,
  'viewer can list the account they blocked');
select lives_ok(
  $$select public.unblock_user(
    '80000000-0000-0000-0000-000000000001'
  )$$,
  'viewer can explicitly unblock the account'
);
select is((select count(*) from public.public_reviews), 1::bigint,
  'unblocked author review is visible again');
select is((select count(*) from public.published_spots), 1::bigint,
  'unblocked author spot is visible again');

select * from finish();
rollback;
