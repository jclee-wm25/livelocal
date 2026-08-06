begin;

create type public.account_appeal_status as enum (
  'submitted',
  'under_review',
  'upheld',
  'dismissed',
  'withdrawn'
);

create table public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default clock_timestamp(),
  updated_by uuid references auth.users(id) on delete restrict
);

insert into public.app_settings (key, value)
values ('moderation_evidence_retention_days', '180'::jsonb);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  action text not null check (char_length(action) between 3 and 100),
  target_type text not null check (char_length(target_type) between 2 and 60),
  target_id uuid,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default clock_timestamp()
);

create index audit_events_target_history
  on public.audit_events(target_type, target_id, occurred_at desc);

create table public.account_access_decisions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status public.account_access_status not null,
  public_message text,
  internal_reason text not null check (char_length(btrim(internal_reason)) >= 3),
  starts_at timestamptz not null,
  ends_at timestamptz,
  access_version integer not null check (access_version > 0),
  actor_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique (user_id, access_version),
  constraint access_decision_public_message check (
    status not in ('restricted', 'banned')
    or char_length(btrim(public_message)) >= 3
  )
);

create table public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('pending', 'cancelled', 'completed')),
  requested_at timestamptz not null default clock_timestamp(),
  scheduled_for timestamptz not null,
  cancelled_at timestamptz,
  completed_at timestamptz,
  constraint account_deletion_terminal_time check (
    (status = 'pending' and cancelled_at is null and completed_at is null)
    or (status = 'cancelled' and cancelled_at is not null and completed_at is null)
    or (status = 'completed' and completed_at is not null)
  )
);

create unique index account_deletion_one_pending
  on public.account_deletion_requests(user_id)
  where status = 'pending';

create table public.account_appeals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  related_decision_id uuid not null
    references public.account_access_decisions(id) on delete restrict,
  reason text not null
    check (reason in ('mistake', 'context', 'account_compromised', 'other')),
  explanation text check (char_length(explanation) <= 2000),
  status public.account_appeal_status not null default 'submitted',
  outcome_reason text,
  decided_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  decided_at timestamptz
);

create unique index account_appeals_one_active_per_decision
  on public.account_appeals(user_id, related_decision_id)
  where status in ('submitted', 'under_review');

create or replace function private.effective_account_status(target_user_id uuid)
returns public.account_access_status
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case
    when aa.status = 'restricted'
      and aa.ends_at is not null
      and aa.ends_at <= clock_timestamp()
      then 'active'::public.account_access_status
    else aa.status
  end
  from public.account_access aa
  where aa.user_id = target_user_id;
$$;

revoke all on function private.effective_account_status(uuid) from public;

create or replace function private.can_use_protected_features()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth, private
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from auth.users u
      where u.id = auth.uid()
        and u.email_confirmed_at is not null
        and private.effective_account_status(u.id) = 'active'
    );
$$;

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
    'access_status', private.effective_account_status(p.id)::text,
    'access_message', aa.public_message,
    'access_ends_at', aa.ends_at,
    'deletion_scheduled_for', aa.deletion_scheduled_for,
    'access_version', aa.version,
    'access_decision_id', decision.id
  )
  from public.profiles p
  join public.account_access aa on aa.user_id = p.id
  left join lateral (
    select aad.id
    from public.account_access_decisions aad
    where aad.user_id = p.id
    order by aad.access_version desc
    limit 1
  ) decision on true
  where p.id = auth.uid();
$$;

create or replace function public.update_my_profile(new_display_name text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  normalized_name text := btrim(new_display_name);
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot update a profile';
  end if;
  if char_length(normalized_name) < 2 or char_length(normalized_name) > 80 then
    raise exception using errcode = '22023', message = 'Invalid display name';
  end if;

  update public.profiles
  set display_name = normalized_name,
      updated_at = clock_timestamp()
  where id = auth.uid();
end;
$$;

create or replace function public.update_my_avatar(new_avatar_path text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot update an avatar';
  end if;
  if new_avatar_path !~ ('^' || auth.uid()::text || '/avatar\\.(jpg|png|webp)$') then
    raise exception using errcode = '22023', message = 'Invalid avatar path';
  end if;

  update public.profiles
  set avatar_path = new_avatar_path,
      updated_at = clock_timestamp()
  where id = auth.uid();
end;
$$;

create or replace function public.request_account_deletion()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  scheduled_at timestamptz := clock_timestamp() + interval '14 days';
begin
  if actor is null or private.effective_account_status(actor) <> 'active' then
    raise exception using errcode = '42501', message = 'Account cannot request deletion';
  end if;

  insert into public.account_deletion_requests (
    user_id, status, scheduled_for
  ) values (
    actor, 'pending', scheduled_at
  );

  update public.account_access
  set status = 'deletion_pending',
      public_message = 'Your account is disabled while deletion is pending.',
      internal_reason = 'User requested account deletion',
      starts_at = clock_timestamp(),
      ends_at = null,
      deletion_scheduled_for = scheduled_at,
      version = version + 1,
      updated_at = clock_timestamp(),
      updated_by = actor
  where user_id = actor;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason
  ) values (
    actor, 'account.deletion_requested', 'account', actor,
    'User requested account deletion'
  );
end;
$$;

create or replace function public.cancel_account_deletion()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  update public.account_deletion_requests
  set status = 'cancelled',
      cancelled_at = clock_timestamp()
  where user_id = actor and status = 'pending';

  if not found then
    raise exception using errcode = 'P0002', message = 'No pending deletion request';
  end if;

  update public.account_access
  set status = 'active',
      public_message = null,
      internal_reason = null,
      starts_at = clock_timestamp(),
      ends_at = null,
      deletion_scheduled_for = null,
      version = version + 1,
      updated_at = clock_timestamp(),
      updated_by = actor
  where user_id = actor and status = 'deletion_pending';

  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason
  ) values (
    actor, 'account.deletion_cancelled', 'account', actor,
    'User recovered account during grace period'
  );
end;
$$;

create or replace function public.submit_account_appeal(
  p_related_decision_id uuid,
  p_appeal_reason text,
  p_appeal_explanation text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  created public.account_appeals;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if p_appeal_reason not in ('mistake', 'context', 'account_compromised', 'other') then
    raise exception using errcode = '22023', message = 'Invalid appeal reason';
  end if;
  if not exists (
    select 1
    from public.account_access_decisions aad
    where aad.id = p_related_decision_id
      and aad.user_id = auth.uid()
      and aad.status in ('restricted', 'banned')
  ) then
    raise exception using errcode = '42501', message = 'Decision cannot be appealed';
  end if;

  insert into public.account_appeals (
    user_id, related_decision_id, reason, explanation
  ) values (
    auth.uid(), p_related_decision_id, p_appeal_reason,
    nullif(btrim(p_appeal_explanation), '')
  ) returning * into created;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason
  ) values (
    auth.uid(), 'account.appeal_submitted', 'account_appeal', created.id,
    p_appeal_reason
  );

  return jsonb_build_object(
    'id', created.id,
    'related_decision_id', created.related_decision_id,
    'status', created.status,
    'created_at', created.created_at
  );
end;
$$;

create or replace function public.admin_set_account_access(
  p_target_user_id uuid,
  p_new_status public.account_access_status,
  p_public_message text,
  p_internal_reason text,
  p_restriction_ends_at timestamptz,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  actor uuid := auth.uid();
  current_access public.account_access;
  new_decision_id uuid;
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  if p_target_user_id = actor then
    raise exception using errcode = '22023', message = 'Admins cannot restrict themselves';
  end if;
  if p_new_status not in ('active', 'restricted', 'banned') then
    raise exception using errcode = '22023', message = 'Invalid access transition';
  end if;
  if char_length(btrim(p_internal_reason)) < 3 then
    raise exception using errcode = '22023', message = 'A reason is required';
  end if;
  if p_new_status in ('restricted', 'banned')
      and char_length(btrim(p_public_message)) < 3 then
    raise exception using errcode = '22023', message = 'A user-facing message is required';
  end if;
  if p_new_status = 'restricted'
      and p_restriction_ends_at is not null
      and p_restriction_ends_at <= clock_timestamp() then
    raise exception using errcode = '22023', message = 'Restriction end must be in the future';
  end if;

  select * into current_access
  from public.account_access
  where user_id = p_target_user_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Target account not found';
  end if;
  if current_access.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Account state changed concurrently';
  end if;
  if private.current_role(p_target_user_id) = 'admin'
      and p_new_status <> 'active'
      and (
        select count(*)
        from public.user_roles ur
        join public.account_access aa on aa.user_id = ur.user_id
        where ur.role = 'admin'
          and ur.revoked_at is null
          and private.effective_account_status(ur.user_id) = 'active'
      ) <= 1 then
    raise exception using errcode = '23514', message = 'Cannot restrict the last active admin';
  end if;

  update public.account_access
  set status = p_new_status,
      public_message = case when p_new_status = 'active' then null else btrim(p_public_message) end,
      internal_reason = btrim(p_internal_reason),
      starts_at = clock_timestamp(),
      ends_at = case when p_new_status = 'restricted' then p_restriction_ends_at else null end,
      deletion_scheduled_for = null,
      version = version + 1,
      updated_at = clock_timestamp(),
      updated_by = actor
  where user_id = p_target_user_id;

  insert into public.account_access_decisions (
    user_id, status, public_message, internal_reason, starts_at, ends_at,
    access_version, actor_id
  ) values (
    p_target_user_id, p_new_status,
    case when p_new_status = 'active' then null else btrim(p_public_message) end,
    btrim(p_internal_reason), clock_timestamp(),
    case when p_new_status = 'restricted' then p_restriction_ends_at else null end,
    p_expected_version + 1, actor
  ) returning id into new_decision_id;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason,
    metadata
  ) values (
    actor, 'admin.account_access_changed', 'account', p_target_user_id,
    btrim(p_internal_reason),
    jsonb_build_object(
      'from_status', current_access.status,
      'to_status', p_new_status,
      'decision_id', new_decision_id,
      'version', p_expected_version + 1
    )
  );

  if p_new_status in ('restricted', 'banned') then
    delete from auth.sessions where user_id::text = p_target_user_id::text;
    delete from auth.refresh_tokens where user_id::text = p_target_user_id::text;
  end if;

  return jsonb_build_object(
    'decision_id', new_decision_id,
    'version', p_expected_version + 1,
    'status', p_new_status
  );
end;
$$;

revoke all on function public.update_my_profile(text) from public;
revoke all on function public.update_my_avatar(text) from public;
revoke all on function public.request_account_deletion() from public;
revoke all on function public.cancel_account_deletion() from public;
revoke all on function public.submit_account_appeal(uuid, text, text) from public;
revoke all on function public.admin_set_account_access(
  uuid, public.account_access_status, text, text, timestamptz, integer
) from public;

grant execute on function public.update_my_profile(text) to authenticated;
grant execute on function public.update_my_avatar(text) to authenticated;
grant execute on function public.request_account_deletion() to authenticated;
grant execute on function public.cancel_account_deletion() to authenticated;
grant execute on function public.submit_account_appeal(uuid, text, text) to authenticated;
grant execute on function public.admin_set_account_access(
  uuid, public.account_access_status, text, text, timestamptz, integer
) to authenticated;

alter table public.app_settings enable row level security;
alter table public.audit_events enable row level security;
alter table public.account_access_decisions enable row level security;
alter table public.account_deletion_requests enable row level security;
alter table public.account_appeals enable row level security;

create policy audit_events_select_admin
  on public.audit_events for select to authenticated
  using (private.is_admin());

create policy account_access_decisions_select_self
  on public.account_access_decisions for select to authenticated
  using (user_id = auth.uid());

create policy account_access_decisions_select_admin
  on public.account_access_decisions for select to authenticated
  using (private.is_admin());

create policy deletion_requests_select_self
  on public.account_deletion_requests for select to authenticated
  using (user_id = auth.uid());

create policy deletion_requests_select_admin
  on public.account_deletion_requests for select to authenticated
  using (private.is_admin());

create policy account_appeals_select_self
  on public.account_appeals for select to authenticated
  using (user_id = auth.uid());

create policy account_appeals_select_admin
  on public.account_appeals for select to authenticated
  using (private.is_admin());

revoke all on table public.app_settings from anon, authenticated;
revoke all on table public.audit_events from anon, authenticated;
revoke all on table public.account_access_decisions from anon, authenticated;
revoke all on table public.account_deletion_requests from anon, authenticated;
revoke all on table public.account_appeals from anon, authenticated;
grant select on table public.audit_events to authenticated;
grant select on table public.account_access_decisions to authenticated;
grant select on table public.account_deletion_requests to authenticated;
grant select on table public.account_appeals to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars', 'avatars', true, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy avatar_insert_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.can_use_protected_features()
  );

create policy avatar_update_own
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.can_use_protected_features()
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.can_use_protected_features()
  );

create policy avatar_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

commit;
