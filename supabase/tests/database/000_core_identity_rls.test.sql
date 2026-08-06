begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

select has_table('public', 'profiles', 'profiles table exists');
select has_table('public', 'user_roles', 'user_roles table exists');
select has_table('public', 'account_access', 'account_access table exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'profiles has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.user_roles'::regclass),
  'user_roles has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.account_access'::regclass),
  'account_access has RLS enabled'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values (
  '00000000-0000-0000-0000-000000000000',
  '10000000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'tourist-one@example.test',
  crypt('test-password', gen_salt('bf')),
  clock_timestamp(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"Tourist One","role":"admin"}'::jsonb,
  clock_timestamp(),
  clock_timestamp()
);

select is(
  (
    select role::text
    from public.user_roles
    where user_id = '10000000-0000-0000-0000-000000000001'
      and revoked_at is null
  ),
  'tourist',
  'public sign-up metadata cannot assign admin'
);

set local role anon;
select throws_ok(
  $$select count(*) from public.profiles$$,
  '42501', 'permission denied for table profiles',
  'anonymous clients cannot read private profiles'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.profiles),
  1::bigint,
  'authenticated user sees own profile'
);

select throws_ok(
  $$insert into public.user_roles (user_id, role)
    values ('10000000-0000-0000-0000-000000000001', 'admin')$$,
  '42501',
  null,
  'authenticated user cannot insert a privileged role'
);

select * from finish();
rollback;
