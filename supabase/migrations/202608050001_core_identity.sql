begin;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

create type public.app_role as enum ('tourist', 'influencer', 'admin');
create type public.account_access_status as enum (
  'active',
  'restricted',
  'banned',
  'deletion_pending',
  'deleted'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null
    check (char_length(btrim(display_name)) between 2 and 80),
  avatar_path text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  granted_at timestamptz not null default clock_timestamp(),
  granted_by uuid references auth.users(id) on delete restrict,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete restrict,
  constraint user_roles_revocation_pair check (
    (revoked_at is null and revoked_by is null)
    or (revoked_at is not null and revoked_by is not null)
  )
);

create unique index user_roles_one_active_role
  on public.user_roles(user_id)
  where revoked_at is null;

create index user_roles_active_role_lookup
  on public.user_roles(role, user_id)
  where revoked_at is null;

create table public.account_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status public.account_access_status not null default 'active',
  public_message text,
  internal_reason text,
  starts_at timestamptz not null default clock_timestamp(),
  ends_at timestamptz,
  deletion_scheduled_for timestamptz,
  version integer not null default 1 check (version > 0),
  updated_at timestamptz not null default clock_timestamp(),
  updated_by uuid references auth.users(id) on delete restrict,
  constraint account_access_time_order check (
    ends_at is null or ends_at > starts_at
  ),
  constraint account_access_deletion_date check (
    (status = 'deletion_pending' and deletion_scheduled_for is not null)
    or (status <> 'deletion_pending' and deletion_scheduled_for is null)
  )
);

create or replace function private.current_role(target_user_id uuid default auth.uid())
returns public.app_role
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(
    (
      select ur.role
      from public.user_roles ur
      where ur.user_id = target_user_id
        and ur.revoked_at is null
      limit 1
    ),
    'tourist'::public.app_role
  );
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.account_access aa on aa.user_id = ur.user_id
    where ur.user_id = auth.uid()
      and ur.role = 'admin'
      and ur.revoked_at is null
      and aa.status = 'active'
      and (aa.ends_at is null or aa.ends_at > clock_timestamp())
  );
$$;

create or replace function private.can_use_protected_features()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from auth.users u
      join public.account_access aa on aa.user_id = u.id
      where u.id = auth.uid()
        and u.email_confirmed_at is not null
        and aa.status = 'active'
        and (aa.ends_at is null or aa.ends_at > clock_timestamp())
    );
$$;

revoke all on function private.current_role(uuid) from public;
revoke all on function private.is_admin() from public;
revoke all on function private.can_use_protected_features() from public;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.can_use_protected_features() to authenticated;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  requested_name text;
begin
  requested_name := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  if char_length(requested_name) < 2 or char_length(requested_name) > 80 then
    requested_name := 'Local explorer';
  end if;

  insert into public.profiles (id, display_name)
  values (new.id, requested_name);

  -- Public metadata is deliberately ignored for role assignment.
  insert into public.user_roles (user_id, role)
  values (new.id, 'tourist');

  insert into public.account_access (user_id, status)
  values (new.id, 'active');

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

create or replace function public.get_my_account()
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public, auth, private
as $$
  select jsonb_build_object(
    'display_name', p.display_name,
    'avatar_url', p.avatar_path,
    'role', private.current_role(auth.uid())::text,
    'access_status', aa.status::text,
    'access_message', aa.public_message,
    'access_ends_at', aa.ends_at,
    'deletion_scheduled_for', aa.deletion_scheduled_for,
    'access_version', aa.version
  )
  from public.profiles p
  join public.account_access aa on aa.user_id = p.id
  where p.id = auth.uid();
$$;

revoke all on function public.get_my_account() from public;
grant execute on function public.get_my_account() to authenticated;

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.account_access enable row level security;

create policy profiles_select_self
  on public.profiles for select
  to authenticated
  using (id = auth.uid());

create policy profiles_select_admin
  on public.profiles for select
  to authenticated
  using (private.is_admin());

create policy user_roles_select_self
  on public.user_roles for select
  to authenticated
  using (user_id = auth.uid());

create policy user_roles_select_admin
  on public.user_roles for select
  to authenticated
  using (private.is_admin());

create policy account_access_select_self
  on public.account_access for select
  to authenticated
  using (user_id = auth.uid());

create policy account_access_select_admin
  on public.account_access for select
  to authenticated
  using (private.is_admin());

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.user_roles from anon, authenticated;
revoke all on table public.account_access from anon, authenticated;
grant select on table public.profiles to authenticated;
grant select on table public.user_roles to authenticated;
grant select on table public.account_access to authenticated;

commit;
