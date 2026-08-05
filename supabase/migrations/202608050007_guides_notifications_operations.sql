begin;

create table public.guides (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid references auth.users(id) on delete set null,
  current_revision_id uuid,
  published_revision_id uuid,
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default clock_timestamp(),
  archived_at timestamptz
);

create table public.guide_revisions (
  id uuid primary key default gen_random_uuid(),
  guide_id uuid not null references public.guides(id) on delete cascade,
  revision_number integer not null check (revision_number > 0),
  author_id uuid references auth.users(id) on delete set null,
  status public.content_revision_status not null default 'draft',
  title text not null check (char_length(btrim(title)) between 3 and 160),
  location_name text not null
    check (char_length(btrim(location_name)) between 2 and 120),
  state text not null check (char_length(btrim(state)) between 2 and 80),
  route_overview text not null
    check (char_length(btrim(route_overview)) between 20 and 3000),
  stops jsonb not null check (
    jsonb_typeof(stops) = 'array'
    and jsonb_array_length(stops) between 1 and 30
  ),
  walking_sequence jsonb not null check (
    jsonb_typeof(walking_sequence) = 'array'
    and jsonb_array_length(walking_sequence) between 1 and 30
  ),
  estimated_duration text not null
    check (char_length(btrim(estimated_duration)) between 2 and 80),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (guide_id, revision_number),
  constraint guide_steps_align check (
    jsonb_array_length(stops) = jsonb_array_length(walking_sequence)
  )
);

alter table public.guides
  add constraint guides_current_revision_fk foreign key (current_revision_id)
    references public.guide_revisions(id) on delete set null,
  add constraint guides_published_revision_fk foreign key (published_revision_id)
    references public.guide_revisions(id) on delete set null;

create table public.guide_publication_decisions (
  id uuid primary key default gen_random_uuid(),
  guide_id uuid not null references public.guides(id) on delete cascade,
  revision_id uuid not null references public.guide_revisions(id) on delete restrict,
  decision text not null check (decision in ('published', 'archived')),
  reason text not null check (char_length(btrim(reason)) between 3 and 1000),
  actor_id uuid references auth.users(id) on delete set null,
  guide_version integer not null,
  created_at timestamptz not null default clock_timestamp(),
  unique (guide_id, guide_version)
);

create table public.published_guides (
  id uuid primary key references public.guides(id) on delete cascade,
  revision_id uuid not null unique
    references public.guide_revisions(id) on delete restrict,
  title text not null,
  location_name text not null,
  state text not null,
  route_overview text not null,
  stops jsonb not null,
  walking_sequence jsonb not null,
  estimated_duration text not null,
  published_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create index published_guides_discovery
  on public.published_guides(state, updated_at desc, id);

create or replace function private.valid_text_array(
  p_values jsonb,
  p_max_item_length integer
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select jsonb_typeof(p_values) = 'array'
    and jsonb_array_length(p_values) between 1 and 30
    and not exists (
      select 1 from jsonb_array_elements(p_values) item
      where jsonb_typeof(item) <> 'string'
        or char_length(btrim(item #>> '{}')) not between 2 and p_max_item_length
    );
$$;

revoke all on function private.valid_text_array(jsonb, integer) from public;

create or replace function public.admin_save_guide_draft(
  p_guide_id uuid,
  p_title text,
  p_location_name text,
  p_state text,
  p_route_overview text,
  p_stops jsonb,
  p_walking_sequence jsonb,
  p_estimated_duration text,
  p_expected_version integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare entity public.guides;
declare revision public.guide_revisions;
declare revision_number integer;
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  if not private.valid_text_array(p_stops, 300)
      or not private.valid_text_array(p_walking_sequence, 500)
      or jsonb_array_length(p_stops) <> jsonb_array_length(p_walking_sequence) then
    raise exception using errcode = '22023', message = 'Invalid guide stops';
  end if;

  if p_guide_id is null then
    insert into public.guides (creator_id) values (auth.uid())
    returning * into entity;
    revision_number := 1;
  else
    select * into entity from public.guides where id = p_guide_id for update;
    if not found or entity.archived_at is not null then
      raise exception using errcode = 'P0002', message = 'Guide not found';
    end if;
    if entity.version <> p_expected_version then
      raise exception using errcode = '40001', message = 'Guide changed concurrently';
    end if;
    select coalesce(max(gr.revision_number), 0) + 1 into revision_number
    from public.guide_revisions gr where gr.guide_id = entity.id;
  end if;

  insert into public.guide_revisions (
    guide_id, revision_number, author_id, title, location_name, state,
    route_overview, stops, walking_sequence, estimated_duration
  ) values (
    entity.id, revision_number, auth.uid(), btrim(p_title),
    btrim(p_location_name), btrim(p_state), btrim(p_route_overview),
    p_stops, p_walking_sequence, btrim(p_estimated_duration)
  ) returning * into revision;
  update public.guides set current_revision_id = revision.id,
    version = version + case when p_guide_id is null then 0 else 1 end
  where id = entity.id returning * into entity;
  return jsonb_build_object(
    'guide_id', entity.id, 'revision_id', revision.id,
    'version', entity.version, 'status', revision.status
  );
end;
$$;

create or replace function public.admin_publish_guide_revision(
  p_revision_id uuid,
  p_reason text,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare entity public.guides;
declare revision public.guide_revisions;
declare next_version integer;
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  if char_length(btrim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'Publication reason required';
  end if;
  select * into revision from public.guide_revisions
  where id = p_revision_id and status = 'draft' for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Guide draft not found';
  end if;
  select * into entity from public.guides
  where id = revision.guide_id for update;
  if entity.version <> p_expected_version
      or entity.current_revision_id <> revision.id then
    raise exception using errcode = '40001', message = 'Guide changed concurrently';
  end if;
  next_version := entity.version + 1;
  update public.guide_revisions set status = 'approved',
    updated_at = clock_timestamp() where id = revision.id;
  update public.guides set published_revision_id = revision.id,
    version = next_version where id = entity.id;
  insert into public.published_guides (
    id, revision_id, title, location_name, state, route_overview,
    stops, walking_sequence, estimated_duration
  ) values (
    entity.id, revision.id, revision.title, revision.location_name,
    revision.state, revision.route_overview, revision.stops,
    revision.walking_sequence, revision.estimated_duration
  ) on conflict (id) do update set
    revision_id = excluded.revision_id,
    title = excluded.title,
    location_name = excluded.location_name,
    state = excluded.state,
    route_overview = excluded.route_overview,
    stops = excluded.stops,
    walking_sequence = excluded.walking_sequence,
    estimated_duration = excluded.estimated_duration,
    updated_at = clock_timestamp();
  insert into public.guide_publication_decisions (
    guide_id, revision_id, decision, reason, actor_id, guide_version
  ) values (
    entity.id, revision.id, 'published', btrim(p_reason), auth.uid(), next_version
  );
  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason, metadata
  ) values (
    auth.uid(), 'admin.guide_published', 'guide', entity.id, btrim(p_reason),
    jsonb_build_object('revision_id', revision.id, 'version', next_version)
  );
  return jsonb_build_object(
    'guide_id', entity.id, 'revision_id', revision.id,
    'version', next_version, 'status', 'approved'
  );
end;
$$;

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (char_length(type) between 3 and 80),
  title text not null check (char_length(btrim(title)) between 3 and 160),
  body text not null check (char_length(btrim(body)) between 3 and 1000),
  target_type text,
  target_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default clock_timestamp()
);

create index notifications_user_unread
  on public.notifications(user_id, created_at desc) where read_at is null;

create or replace function private.create_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_target_type text default null,
  p_target_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if p_user_id is null then return; end if;
  insert into public.notifications (
    user_id, type, title, body, target_type, target_id
  ) values (
    p_user_id, p_type, btrim(p_title), btrim(p_body), p_target_type, p_target_id
  );
end;
$$;

revoke all on function private.create_notification(
  uuid, text, text, text, text, uuid
) from public;

create or replace function private.notify_spot_decision()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare recipient uuid;
begin
  select owner_id into recipient from public.spots where id = new.spot_id;
  perform private.create_notification(
    recipient, 'spot_' || new.decision,
    case when new.decision = 'approved' then 'Spot approved' else 'Spot needs changes' end,
    new.reason, 'spot', new.spot_id
  );
  return new;
end;
$$;

create trigger spot_decision_notification
after insert on public.spot_moderation_decisions
for each row execute function private.notify_spot_decision();

create or replace function private.notify_restaurant_decision()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare recipient uuid;
begin
  select owner_id into recipient from public.restaurants where id = new.restaurant_id;
  perform private.create_notification(
    recipient, 'restaurant_' || new.decision,
    case when new.decision = 'approved'
      then 'Restaurant approved' else 'Restaurant needs changes' end,
    new.reason, 'restaurant', new.restaurant_id
  );
  return new;
end;
$$;

create trigger restaurant_decision_notification
after insert on public.restaurant_moderation_decisions
for each row execute function private.notify_restaurant_decision();

create or replace function private.notify_influencer_decision()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare recipient uuid;
begin
  select user_id into recipient from public.influencer_applications
  where id = new.application_id;
  perform private.create_notification(
    recipient, 'creator_application_' || new.decision,
    case new.decision
      when 'approved' then 'Creator application approved'
      when 'needs_information' then 'Creator application needs information'
      else 'Creator application decision'
    end,
    new.reason, 'influencer_application', new.application_id
  );
  return new;
end;
$$;

create trigger influencer_decision_notification
after insert on public.influencer_application_decisions
for each row execute function private.notify_influencer_decision();

create or replace function private.notify_report_decision()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare moderation_case public.moderation_cases;
declare author_id uuid;
begin
  select * into moderation_case from public.moderation_cases
  where id = new.case_id;
  perform private.create_notification(
    moderation_case.reporter_id, 'report_' || new.decision,
    'Report reviewed',
    case new.decision
      when 'upheld' then 'The reported content was actioned.'
      when 'dismissed' then 'The report was reviewed and dismissed.'
      else 'The report was escalated for further review.'
    end,
    moderation_case.target_type, moderation_case.target_id
  );
  if new.decision = 'upheld' then
    if moderation_case.target_type = 'review' then
      select user_id into author_id from public.reviews
      where id = moderation_case.target_id;
    elsif moderation_case.target_type = 'spot' then
      select owner_id into author_id from public.spots
      where id = moderation_case.target_id;
    elsif moderation_case.target_type = 'restaurant' then
      select owner_id into author_id from public.restaurants
      where id = moderation_case.target_id;
    end if;
    perform private.create_notification(
      author_id, 'content_moderated', 'Content moderation action',
      new.reason, moderation_case.target_type, moderation_case.target_id
    );
  end if;
  return new;
end;
$$;

create trigger report_decision_notification
after insert on public.moderation_decisions
for each row execute function private.notify_report_decision();

create or replace function private.notify_account_access_decision()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if new.status <> 'active' then
    perform private.create_notification(
      new.user_id, 'account_' || new.status, 'Account access changed',
      new.public_message, 'account_access_decision', new.id
    );
  end if;
  return new;
end;
$$;

create trigger account_access_decision_notification
after insert on public.account_access_decisions
for each row execute function private.notify_account_access_decision();

create or replace function public.mark_notifications_read(
  p_notification_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare changed integer;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot update notifications';
  end if;
  update public.notifications set read_at = clock_timestamp()
  where user_id = auth.uid() and read_at is null
    and (p_notification_id is null or id = p_notification_id);
  get diagnostics changed = row_count;
  return changed;
end;
$$;

create or replace function public.admin_platform_statistics()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  return jsonb_build_object(
    'accounts_total', (select count(*) from public.profiles),
    'accounts_restricted', (
      select count(*) from public.account_access
      where private.effective_account_status(user_id) <> 'active'
    ),
    'spots_published', (select count(*) from public.published_spots),
    'restaurants_published', (select count(*) from public.published_restaurants),
    'guides_published', (select count(*) from public.published_guides),
    'reviews_published', (select count(*) from public.public_reviews),
    'moderation_pending', (
      select count(*) from public.moderation_cases where status = 'pending'
    ),
    'creator_applications_pending', (
      select count(*) from public.influencer_applications
      where status in ('submitted', 'under_review')
    )
  );
end;
$$;

create or replace function public.admin_list_audit_events(
  p_limit integer default 50,
  p_before timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare result jsonb;
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  select coalesce(jsonb_agg(to_jsonb(event_row)), '[]'::jsonb) into result
  from (
    select event.id, event.action, event.target_type, event.target_id,
      event.reason, event.occurred_at,
      coalesce(profile.display_name, 'System or deleted admin') as actor_name
    from public.audit_events event
    left join public.profiles profile on profile.id = event.actor_id
    where p_before is null or event.occurred_at < p_before
    order by event.occurred_at desc
    limit least(greatest(p_limit, 1), 100)
  ) event_row;
  return result;
end;
$$;

alter table public.moderation_cases
  add column legal_hold boolean not null default false,
  add column legal_hold_reason text,
  add column legal_hold_set_at timestamptz,
  add column legal_hold_set_by uuid references auth.users(id) on delete set null,
  add constraint moderation_case_legal_hold_details check (
    (not legal_hold and legal_hold_reason is null and legal_hold_set_at is null)
    or (legal_hold and char_length(btrim(legal_hold_reason)) >= 3
      and legal_hold_set_at is not null)
  );

create or replace function public.purge_expired_moderation_evidence()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare retention_days integer;
declare removed integer;
begin
  if coalesce(auth.role(), '') <> 'service_role'
      and current_user not in ('postgres', 'supabase_admin') then
    raise exception using errcode = '42501', message = 'Service role required';
  end if;
  select greatest(1, least(3650, (value #>> '{}')::integer))
  into retention_days from public.app_settings
  where key = 'moderation_evidence_retention_days';
  retention_days := coalesce(retention_days, 180);
  delete from public.moderation_cases
  where status in ('upheld', 'dismissed') and not legal_hold
    and decided_at < clock_timestamp() - make_interval(days => retention_days);
  get diagnostics removed = row_count;
  return removed;
end;
$$;

-- Identity deletion must not be blocked by historical actor references. The
-- target records remain while the deleted actor reference becomes null.
alter table public.user_roles alter column granted_by drop not null;
alter table public.user_roles drop constraint user_roles_granted_by_fkey;
alter table public.user_roles add constraint user_roles_granted_by_fkey
  foreign key (granted_by) references auth.users(id) on delete set null;
alter table public.user_roles drop constraint user_roles_revoked_by_fkey;
alter table public.user_roles add constraint user_roles_revoked_by_fkey
  foreign key (revoked_by) references auth.users(id) on delete set null;
alter table public.account_access drop constraint account_access_updated_by_fkey;
alter table public.account_access add constraint account_access_updated_by_fkey
  foreign key (updated_by) references auth.users(id) on delete set null;
alter table public.app_settings drop constraint app_settings_updated_by_fkey;
alter table public.app_settings add constraint app_settings_updated_by_fkey
  foreign key (updated_by) references auth.users(id) on delete set null;
alter table public.account_access_decisions alter column actor_id drop not null;
alter table public.account_access_decisions
  drop constraint account_access_decisions_actor_id_fkey;
alter table public.account_access_decisions
  add constraint account_access_decisions_actor_id_fkey
  foreign key (actor_id) references auth.users(id) on delete set null;
alter table public.spot_moderation_decisions alter column actor_id drop not null;
alter table public.spot_moderation_decisions
  drop constraint spot_moderation_decisions_actor_id_fkey;
alter table public.spot_moderation_decisions
  add constraint spot_moderation_decisions_actor_id_fkey
  foreign key (actor_id) references auth.users(id) on delete set null;
alter table public.restaurant_moderation_decisions alter column actor_id drop not null;
alter table public.restaurant_moderation_decisions
  drop constraint restaurant_moderation_decisions_actor_id_fkey;
alter table public.restaurant_moderation_decisions
  add constraint restaurant_moderation_decisions_actor_id_fkey
  foreign key (actor_id) references auth.users(id) on delete set null;
alter table public.influencer_application_decisions alter column actor_id drop not null;
alter table public.influencer_application_decisions
  drop constraint influencer_application_decisions_actor_id_fkey;
alter table public.influencer_application_decisions
  add constraint influencer_application_decisions_actor_id_fkey
  foreign key (actor_id) references auth.users(id) on delete set null;
alter table public.moderation_decisions alter column actor_id drop not null;
alter table public.moderation_decisions
  drop constraint moderation_decisions_actor_id_fkey;
alter table public.moderation_decisions
  add constraint moderation_decisions_actor_id_fkey
  foreign key (actor_id) references auth.users(id) on delete set null;
alter table public.moderation_cases
  drop constraint moderation_cases_decided_by_fkey;
alter table public.moderation_cases
  add constraint moderation_cases_decided_by_fkey
  foreign key (decided_by) references auth.users(id) on delete set null;
alter table public.account_appeals
  drop constraint account_appeals_decided_by_fkey;
alter table public.account_appeals
  add constraint account_appeals_decided_by_fkey
  foreign key (decided_by) references auth.users(id) on delete set null;

create or replace function public.finalize_due_account_deletions()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth, storage
as $$
declare due record;
declare completed integer := 0;
begin
  if coalesce(auth.role(), '') <> 'service_role'
      and current_user not in ('postgres', 'supabase_admin') then
    raise exception using errcode = '42501', message = 'Service role required';
  end if;
  for due in
    select request.id, request.user_id
    from public.account_deletion_requests request
    where request.status = 'pending'
      and request.scheduled_for <= clock_timestamp()
    order by request.scheduled_for
    for update skip locked
  loop
    update public.reviews set user_id = null,
      author_display_name = 'Deleted user', version = version + 1,
      updated_at = clock_timestamp()
    where user_id = due.user_id and status = 'published';
    update public.public_reviews public_review set
      author_display_name = 'Deleted user',
      version = review.version,
      updated_at = clock_timestamp()
    from public.reviews review
    where public_review.id = review.id and review.user_id is null
      and public_review.author_display_name <> 'Deleted user';

    delete from public.spots where owner_id = due.user_id
      and approved_revision_id is null;
    update public.spots set owner_id = null where owner_id = due.user_id;
    update public.spot_revisions set author_id = null
      where author_id = due.user_id;
    delete from public.restaurants where owner_id = due.user_id
      and approved_revision_id is null;
    update public.restaurants set owner_id = null, ownership_status = 'unclaimed'
      where owner_id = due.user_id;
    update public.restaurant_revisions set author_id = null
      where author_id = due.user_id;
    update public.published_restaurants set creator_display_name = null,
      ownership_status = 'unclaimed', updated_at = clock_timestamp()
    where id in (
      select id from public.restaurants where ownership_status = 'unclaimed'
    );
    update public.guides set creator_id = null where creator_id = due.user_id;
    update public.guide_revisions set author_id = null
      where author_id = due.user_id;
    delete from auth.users where id = due.user_id;
    completed := completed + 1;
  end loop;
  return completed;
end;
$$;

alter table public.guides enable row level security;
alter table public.guide_revisions enable row level security;
alter table public.guide_publication_decisions enable row level security;
alter table public.published_guides enable row level security;
alter table public.notifications enable row level security;

create policy guides_admin_select on public.guides for select to authenticated
  using (private.is_admin());
create policy guide_revisions_admin_select on public.guide_revisions
  for select to authenticated using (private.is_admin());
create policy guide_decisions_admin_select on public.guide_publication_decisions
  for select to authenticated using (private.is_admin());
create policy published_guides_public_select on public.published_guides
  for select to anon, authenticated
  using (not private.is_content_hidden('guide', id));
create policy notifications_owner_select on public.notifications
  for select to authenticated
  using (user_id = auth.uid() and private.can_use_protected_features());

revoke all on table public.guides from anon, authenticated;
revoke all on table public.guide_revisions from anon, authenticated;
revoke all on table public.guide_publication_decisions from anon, authenticated;
revoke all on table public.published_guides from anon, authenticated;
revoke all on table public.notifications from anon, authenticated;
grant select on table public.guides to authenticated;
grant select on table public.guide_revisions to authenticated;
grant select on table public.guide_publication_decisions to authenticated;
grant select on table public.published_guides to anon, authenticated;
grant select on table public.notifications to authenticated;

revoke all on function public.admin_save_guide_draft(
  uuid, text, text, text, text, jsonb, jsonb, text, integer
) from public;
revoke all on function public.admin_publish_guide_revision(uuid, text, integer)
  from public;
revoke all on function public.mark_notifications_read(uuid) from public;
revoke all on function public.admin_platform_statistics() from public;
revoke all on function public.admin_list_audit_events(integer, timestamptz)
  from public;
revoke all on function public.purge_expired_moderation_evidence() from public;
revoke all on function public.finalize_due_account_deletions() from public;

grant execute on function public.admin_save_guide_draft(
  uuid, text, text, text, text, jsonb, jsonb, text, integer
) to authenticated;
grant execute on function public.admin_publish_guide_revision(uuid, text, integer)
  to authenticated;
grant execute on function public.mark_notifications_read(uuid) to authenticated;
grant execute on function public.admin_platform_statistics() to authenticated;
grant execute on function public.admin_list_audit_events(integer, timestamptz)
  to authenticated;
grant execute on function public.purge_expired_moderation_evidence()
  to service_role;
grant execute on function public.finalize_due_account_deletions()
  to service_role;

commit;
