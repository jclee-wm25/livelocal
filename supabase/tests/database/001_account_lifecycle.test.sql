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
    '20000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'admin@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Admin One"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '20000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'tourist@example.test',
    crypt('test-password', gen_salt('bf')), clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Tourist Two"}'::jsonb,
    clock_timestamp(), clock_timestamp()
  );

update public.user_roles
set revoked_at = clock_timestamp(),
    revoked_by = '20000000-0000-0000-0000-000000000001'
where user_id = '20000000-0000-0000-0000-000000000001'
  and revoked_at is null;

insert into public.user_roles (user_id, role, granted_by)
values (
  '20000000-0000-0000-0000-000000000001',
  'admin',
  '20000000-0000-0000-0000-000000000001'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"20000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;

select lives_ok(
  $$select public.request_account_deletion()$$,
  'active user can request deletion'
);
select is(
  (
    select status::text from public.account_access
    where user_id = auth.uid()
  ),
  'deletion_pending',
  'deletion immediately disables protected account state'
);
select ok(
  (
    select scheduled_for between
      clock_timestamp() + interval '13 days 23 hours'
      and clock_timestamp() + interval '14 days 1 hour'
    from public.account_deletion_requests
    where user_id = auth.uid() and status = 'pending'
  ),
  'deletion uses a 14-day grace period'
);
select throws_ok(
  $$select public.request_account_deletion()$$,
  '42501',
  'Account cannot request deletion',
  'a second pending deletion request is rejected'
);
select lives_ok(
  $$select public.cancel_account_deletion()$$,
  'user can recover during the grace period'
);
select is(
  (
    select status::text from public.account_access
    where user_id = auth.uid()
  ),
  'active',
  'recovery restores active state'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select throws_ok(
  $$select public.admin_set_account_access(
    '20000000-0000-0000-0000-000000000001', 'restricted',
    'Temporary restriction', 'Self action test', null, 1
  )$$,
  '22023',
  'Admins cannot restrict themselves',
  'admin cannot restrict self'
);

select lives_ok(
  $$select public.admin_set_account_access(
    '20000000-0000-0000-0000-000000000002', 'restricted',
    'Temporary restriction', 'Moderation test',
    clock_timestamp() + interval '1 day', 3
  )$$,
  'admin can restrict another account with expected version'
);

select is(
  (
    select count(*) from public.account_access_decisions
    where user_id = '20000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'restriction creates immutable decision history'
);

select throws_ok(
  $$select public.admin_set_account_access(
    '20000000-0000-0000-0000-000000000002', 'banned',
    'Permanent ban', 'Stale admin decision', null, 3
  )$$,
  '40001',
  'Account state changed concurrently',
  'stale moderation version is rejected'
);

select lives_ok(
  $$select public.admin_set_account_access(
    '20000000-0000-0000-0000-000000000002', 'banned',
    'Permanent platform ban', 'Confirmed severe abuse', null, 4
  )$$,
  'admin can permanently ban with the current expected version'
);
select ok(
  (select banned_until > clock_timestamp() from auth.users
    where id = '20000000-0000-0000-0000-000000000002'),
  'permanent platform ban blocks fresh Auth sessions'
);
select lives_ok(
  $$select public.admin_set_account_access(
    '20000000-0000-0000-0000-000000000002', 'active',
    null, 'Successful appeal restores access', null, 5
  )$$,
  'admin can restore a banned account with the current expected version'
);
select is(
  (select banned_until from auth.users
    where id = '20000000-0000-0000-0000-000000000002'),
  null::timestamptz,
  'restoring account access also restores future Auth sessions'
);

select * from finish();
rollback;
