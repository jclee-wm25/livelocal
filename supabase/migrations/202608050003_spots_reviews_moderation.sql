begin;

create extension if not exists pg_trgm with schema extensions;

create type public.content_revision_status as enum (
  'draft',
  'submitted',
  'under_review',
  'approved',
  'rejected',
  'withdrawn',
  'archived'
);
create type public.review_status as enum ('published', 'removed_by_author', 'removed_by_moderation');
create type public.moderation_case_status as enum (
  'pending', 'under_review', 'upheld', 'dismissed', 'escalated'
);

create table public.spots (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  current_revision_id uuid,
  approved_revision_id uuid,
  moderation_version integer not null default 1 check (moderation_version > 0),
  created_at timestamptz not null default clock_timestamp(),
  archived_at timestamptz
);

create table public.spot_revisions (
  id uuid primary key default gen_random_uuid(),
  spot_id uuid not null references public.spots(id) on delete cascade,
  revision_number integer not null check (revision_number > 0),
  author_id uuid references auth.users(id) on delete set null,
  status public.content_revision_status not null default 'draft',
  name text not null check (char_length(btrim(name)) between 2 and 120),
  category text not null check (char_length(btrim(category)) between 2 and 60),
  description text not null check (char_length(btrim(description)) between 20 and 3000),
  state text not null check (char_length(btrim(state)) between 2 and 80),
  city text not null check (char_length(btrim(city)) between 2 and 100),
  address text not null check (char_length(btrim(address)) between 5 and 300),
  price_range text not null check (price_range in ('$', '$$', '$$$', '$$$$')),
  best_time text not null check (char_length(btrim(best_time)) between 2 and 160),
  things_to_do text not null check (char_length(btrim(things_to_do)) between 2 and 500),
  image_path text,
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  duplicate_override_reason text check (char_length(duplicate_override_reason) <= 500),
  submitted_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (spot_id, revision_number),
  constraint spot_revision_coordinates_pair check (
    (latitude is null and longitude is null)
    or (latitude is not null and longitude is not null)
  )
);

alter table public.spots
  add constraint spots_current_revision_fk foreign key (current_revision_id)
    references public.spot_revisions(id) on delete set null,
  add constraint spots_approved_revision_fk foreign key (approved_revision_id)
    references public.spot_revisions(id) on delete set null;

create table public.spot_moderation_decisions (
  id uuid primary key default gen_random_uuid(),
  spot_id uuid not null references public.spots(id) on delete cascade,
  revision_id uuid not null references public.spot_revisions(id) on delete restrict,
  decision text not null check (decision in ('approved', 'rejected')),
  reason text not null check (char_length(btrim(reason)) between 3 and 1000),
  actor_id uuid not null references auth.users(id) on delete restrict,
  moderation_version integer not null,
  created_at timestamptz not null default clock_timestamp(),
  unique (spot_id, moderation_version)
);

create table public.published_spots (
  id uuid primary key references public.spots(id) on delete cascade,
  revision_id uuid not null unique references public.spot_revisions(id) on delete restrict,
  name text not null,
  category text not null,
  description text not null,
  state text not null,
  city text not null,
  address text not null,
  price_range text not null,
  best_time text not null,
  things_to_do text not null,
  image_path text,
  latitude double precision,
  longitude double precision,
  rating_average numeric(3,2) not null default 0 check (rating_average between 0 and 5),
  review_count integer not null default 0 check (review_count >= 0),
  published_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create index published_spots_discovery_order
  on public.published_spots(updated_at desc, id);
create index published_spots_location_filter
  on public.published_spots(state, city, category);
create index published_spots_name_search
  on public.published_spots using gin (name extensions.gin_trgm_ops);

create or replace function private.normalize_listing_text(value text)
returns text
language sql
immutable
set search_path = pg_catalog
as $$
  select regexp_replace(lower(btrim(coalesce(value, ''))), '[^a-z0-9]+', '', 'g');
$$;

create or replace function private.probable_spot_duplicates(
  p_name text,
  p_address text,
  p_latitude double precision,
  p_longitude double precision,
  p_exclude_spot_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public, private, extensions
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ps.id,
        'name', ps.name,
        'address', ps.address,
        'city', ps.city,
        'state', ps.state
      ) order by ps.name
    ),
    '[]'::jsonb
  )
  from public.published_spots ps
  where (p_exclude_spot_id is null or ps.id <> p_exclude_spot_id)
    and (
      private.normalize_listing_text(ps.name) = private.normalize_listing_text(p_name)
      or private.normalize_listing_text(ps.address) = private.normalize_listing_text(p_address)
      or similarity(lower(ps.name), lower(p_name)) >= 0.72
    )
    and (
      p_latitude is null
      or p_longitude is null
      or ps.latitude is null
      or ps.longitude is null
      or (
        abs(ps.latitude - p_latitude) <= 0.01
        and abs(ps.longitude - p_longitude) <= 0.01
      )
    );
$$;

revoke all on function private.normalize_listing_text(text) from public;
revoke all on function private.probable_spot_duplicates(
  text, text, double precision, double precision, uuid
) from public;

create or replace function public.create_spot_draft(
  p_name text,
  p_category text,
  p_description text,
  p_state text,
  p_city text,
  p_address text,
  p_price_range text,
  p_best_time text,
  p_things_to_do text,
  p_image_path text default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  created_spot_id uuid;
  created_revision_id uuid;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot create spot drafts';
  end if;
  if p_image_path is not null
      and p_image_path !~ ('^' || actor::text || '/[A-Za-z0-9_-]+\\.(jpg|png|webp)$') then
    raise exception using errcode = '22023', message = 'Invalid spot image path';
  end if;

  insert into public.spots (owner_id)
  values (actor)
  returning id into created_spot_id;

  insert into public.spot_revisions (
    spot_id, revision_number, author_id, name, category, description,
    state, city, address, price_range, best_time, things_to_do,
    image_path, latitude, longitude
  ) values (
    created_spot_id, 1, actor, btrim(p_name), btrim(p_category),
    btrim(p_description), btrim(p_state), btrim(p_city), btrim(p_address),
    p_price_range, btrim(p_best_time), btrim(p_things_to_do),
    p_image_path, p_latitude, p_longitude
  ) returning id into created_revision_id;

  update public.spots
  set current_revision_id = created_revision_id
  where id = created_spot_id;

  return jsonb_build_object(
    'spot_id', created_spot_id,
    'revision_id', created_revision_id,
    'image_path', p_image_path,
    'status', 'draft',
    'probable_duplicates', private.probable_spot_duplicates(
      p_name, p_address, p_latitude, p_longitude, created_spot_id
    )
  );
end;
$$;

create or replace function public.delete_spot_draft(p_revision_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_spot_id uuid;
begin
  select s.id into target_spot_id
  from public.spots s
  join public.spot_revisions sr on sr.id = s.current_revision_id
  where s.owner_id = auth.uid()
    and s.approved_revision_id is null
    and sr.id = p_revision_id
    and sr.status = 'draft'
  for update of s;
  if not found then
    raise exception using errcode = 'P0002', message = 'Draft not found';
  end if;
  delete from public.spots where id = target_spot_id;
end;
$$;

create or replace function public.submit_spot_revision(
  p_revision_id uuid,
  p_duplicate_override_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  revision public.spot_revisions;
  duplicate_matches jsonb;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot submit spots';
  end if;

  select sr.* into revision
  from public.spot_revisions sr
  join public.spots s on s.id = sr.spot_id
  where sr.id = p_revision_id
    and s.owner_id = auth.uid()
    and s.current_revision_id = sr.id
  for update of sr;

  if not found then
    raise exception using errcode = 'P0002', message = 'Draft not found';
  end if;
  if revision.status <> 'draft' then
    raise exception using errcode = '22023', message = 'Only a draft can be submitted';
  end if;

  duplicate_matches := private.probable_spot_duplicates(
    revision.name, revision.address, revision.latitude, revision.longitude,
    revision.spot_id
  );
  if jsonb_array_length(duplicate_matches) > 0
      and char_length(btrim(coalesce(p_duplicate_override_reason, ''))) < 10 then
    raise exception using
      errcode = '23505',
      message = 'Probable duplicate requires selection or justified override',
      detail = duplicate_matches::text;
  end if;

  update public.spot_revisions
  set status = 'submitted',
      duplicate_override_reason = nullif(btrim(p_duplicate_override_reason), ''),
      submitted_at = clock_timestamp(),
      updated_at = clock_timestamp()
  where id = revision.id;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, metadata
  ) values (
    auth.uid(), 'spot.revision_submitted', 'spot', revision.spot_id,
    jsonb_build_object('revision_id', revision.id)
  );

  return jsonb_build_object(
    'spot_id', revision.spot_id,
    'revision_id', revision.id,
    'status', 'submitted'
  );
end;
$$;

create or replace function public.revise_spot(p_source_revision_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  source public.spot_revisions;
  next_number integer;
  created_revision_id uuid;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot revise spots';
  end if;

  select sr.* into source
  from public.spot_revisions sr
  join public.spots s on s.id = sr.spot_id
  where sr.id = p_source_revision_id and s.owner_id = auth.uid()
  for update of sr;
  if not found then
    raise exception using errcode = 'P0002', message = 'Spot revision not found';
  end if;
  if source.status not in ('submitted', 'under_review', 'approved', 'rejected') then
    raise exception using errcode = '22023', message = 'Revision cannot be revised';
  end if;

  if source.status in ('submitted', 'under_review') then
    update public.spot_revisions
    set status = 'withdrawn', updated_at = clock_timestamp()
    where id = source.id;
  end if;

  select coalesce(max(revision_number), 0) + 1 into next_number
  from public.spot_revisions where spot_id = source.spot_id;

  insert into public.spot_revisions (
    spot_id, revision_number, author_id, name, category, description,
    state, city, address, price_range, best_time, things_to_do,
    image_path, latitude, longitude
  ) values (
    source.spot_id, next_number, auth.uid(), source.name, source.category,
    source.description, source.state, source.city, source.address,
    source.price_range, source.best_time, source.things_to_do,
    source.image_path, source.latitude, source.longitude
  ) returning id into created_revision_id;

  update public.spots
  set current_revision_id = created_revision_id
  where id = source.spot_id;

  return jsonb_build_object(
    'spot_id', source.spot_id,
    'revision_id', created_revision_id,
    'status', 'draft',
    'revision_number', next_number
  );
end;
$$;

create or replace function public.admin_moderate_spot_revision(
  p_revision_id uuid,
  p_decision text,
  p_reason text,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  revision public.spot_revisions;
  entity public.spots;
  next_version integer;
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  if p_decision not in ('approved', 'rejected') then
    raise exception using errcode = '22023', message = 'Invalid moderation decision';
  end if;
  if char_length(btrim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'A reason is required';
  end if;

  select sr.* into revision
  from public.spot_revisions sr
  where sr.id = p_revision_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'Revision not found';
  end if;

  select * into entity from public.spots
  where id = revision.spot_id for update;
  if entity.moderation_version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Spot changed concurrently';
  end if;
  if entity.current_revision_id <> revision.id
      or revision.status not in ('submitted', 'under_review') then
    raise exception using errcode = '22023', message = 'Revision is not awaiting moderation';
  end if;

  next_version := p_expected_version + 1;
  update public.spots
  set moderation_version = next_version,
      approved_revision_id = case
        when p_decision = 'approved' then revision.id
        else approved_revision_id
      end
  where id = entity.id;

  if p_decision = 'approved' then
    if entity.approved_revision_id is not null then
      update public.spot_revisions
      set status = 'archived', updated_at = clock_timestamp()
      where id = entity.approved_revision_id;
    end if;
    update public.spot_revisions
    set status = 'approved', decided_at = clock_timestamp(),
        updated_at = clock_timestamp()
    where id = revision.id;

    insert into public.published_spots (
      id, revision_id, name, category, description, state, city, address,
      price_range, best_time, things_to_do, image_path, latitude, longitude,
      published_at, updated_at
    ) values (
      entity.id, revision.id, revision.name, revision.category,
      revision.description, revision.state, revision.city, revision.address,
      revision.price_range, revision.best_time, revision.things_to_do,
      revision.image_path, revision.latitude, revision.longitude,
      clock_timestamp(), clock_timestamp()
    ) on conflict (id) do update set
      revision_id = excluded.revision_id,
      name = excluded.name,
      category = excluded.category,
      description = excluded.description,
      state = excluded.state,
      city = excluded.city,
      address = excluded.address,
      price_range = excluded.price_range,
      best_time = excluded.best_time,
      things_to_do = excluded.things_to_do,
      image_path = excluded.image_path,
      latitude = excluded.latitude,
      longitude = excluded.longitude,
      updated_at = clock_timestamp();
  else
    update public.spot_revisions
    set status = 'rejected', decided_at = clock_timestamp(),
        updated_at = clock_timestamp()
    where id = revision.id;
  end if;

  insert into public.spot_moderation_decisions (
    spot_id, revision_id, decision, reason, actor_id, moderation_version
  ) values (
    entity.id, revision.id, p_decision, btrim(p_reason), actor, next_version
  );
  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason, metadata
  ) values (
    actor, 'admin.spot_' || p_decision, 'spot', entity.id, btrim(p_reason),
    jsonb_build_object('revision_id', revision.id, 'version', next_version)
  );

  return jsonb_build_object(
    'spot_id', entity.id,
    'revision_id', revision.id,
    'status', p_decision,
    'version', next_version
  );
end;
$$;

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  target_type text not null check (target_type in ('spot', 'restaurant')),
  target_id uuid not null,
  rating smallint not null check (rating between 1 and 5),
  body text not null check (char_length(btrim(body)) between 3 and 2000),
  author_display_name text not null,
  status public.review_status not null default 'published',
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  removed_at timestamptz
);

create unique index reviews_one_published_per_user_target
  on public.reviews(user_id, target_type, target_id)
  where status = 'published' and user_id is not null;

create table public.review_edit_history (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  prior_rating smallint not null,
  prior_body text not null,
  prior_version integer not null,
  edited_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default clock_timestamp()
);

create table public.public_reviews (
  id uuid primary key references public.reviews(id) on delete cascade,
  target_type text not null,
  target_id uuid not null,
  rating smallint not null,
  body text not null,
  author_display_name text not null,
  version integer not null,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create index public_reviews_target_order
  on public.public_reviews(target_type, target_id, updated_at desc, id);

create table public.moderation_cases (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  target_type text not null check (target_type in ('review', 'spot', 'restaurant', 'guide')),
  target_id uuid not null,
  reason text not null check (
    reason in ('spam', 'harassment', 'hate', 'dangerous', 'misleading', 'privacy', 'other')
  ),
  explanation text check (char_length(explanation) <= 2000),
  status public.moderation_case_status not null default 'pending',
  version integer not null default 1 check (version > 0),
  assigned_to uuid references auth.users(id) on delete set null,
  decision_reason text,
  decided_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  decided_at timestamptz
);

create unique index moderation_cases_no_duplicate_active_report
  on public.moderation_cases(reporter_id, target_type, target_id)
  where reporter_id is not null and status in ('pending', 'under_review', 'escalated');

create table public.moderation_decisions (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.moderation_cases(id) on delete cascade,
  decision public.moderation_case_status not null
    check (decision in ('upheld', 'dismissed', 'escalated')),
  reason text not null check (char_length(btrim(reason)) between 3 and 1000),
  actor_id uuid not null references auth.users(id) on delete restrict,
  case_version integer not null,
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp(),
  unique (case_id, case_version)
);

create table public.hidden_content (
  user_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null check (target_type in ('review', 'spot', 'restaurant', 'guide')),
  target_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key (user_id, target_type, target_id)
);

create or replace function private.is_content_hidden(
  p_target_type text,
  p_target_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null and exists (
    select 1 from public.hidden_content hc
    where hc.user_id = auth.uid()
      and hc.target_type = p_target_type
      and hc.target_id = p_target_id
  );
$$;

revoke all on function private.is_content_hidden(text, uuid) from public;
grant execute on function private.is_content_hidden(text, uuid) to anon, authenticated;

create or replace function private.recalculate_target_rating(
  p_target_type text,
  p_target_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  calculated_average numeric(3,2);
  calculated_count integer;
begin
  select coalesce(round(avg(rating)::numeric, 2), 0), count(*)::integer
  into calculated_average, calculated_count
  from public.reviews
  where target_type = p_target_type
    and target_id = p_target_id
    and status = 'published';

  if p_target_type = 'spot' then
    update public.published_spots
    set rating_average = calculated_average,
        review_count = calculated_count,
        updated_at = clock_timestamp()
    where id = p_target_id;
  end if;
end;
$$;

revoke all on function private.recalculate_target_rating(text, uuid) from public;

create or replace function public.upsert_review(
  p_target_type text,
  p_target_id uuid,
  p_rating integer,
  p_body text,
  p_expected_version integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  existing public.reviews;
  saved public.reviews;
  display_name text;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot write reviews';
  end if;
  if p_target_type <> 'spot'
      or not exists (select 1 from public.published_spots where id = p_target_id) then
    raise exception using errcode = '23503', message = 'Review target is unavailable';
  end if;
  if p_rating not between 1 and 5
      or char_length(btrim(p_body)) not between 3 and 2000 then
    raise exception using errcode = '22023', message = 'Invalid review';
  end if;

  select p.display_name into display_name
  from public.profiles p where p.id = auth.uid();

  select * into existing from public.reviews
  where user_id = auth.uid()
    and target_type = p_target_type
    and target_id = p_target_id
    and status = 'published'
  for update;

  if found then
    if p_expected_version is null or existing.version <> p_expected_version then
      raise exception using errcode = '40001', message = 'Review changed concurrently';
    end if;
    insert into public.review_edit_history (
      review_id, prior_rating, prior_body, prior_version, edited_by
    ) values (
      existing.id, existing.rating, existing.body, existing.version, auth.uid()
    );
    update public.reviews
    set rating = p_rating,
        body = btrim(p_body),
        author_display_name = display_name,
        version = version + 1,
        updated_at = clock_timestamp()
    where id = existing.id returning * into saved;
  else
    if p_expected_version is not null then
      raise exception using errcode = 'P0002', message = 'Review not found';
    end if;
    insert into public.reviews (
      user_id, target_type, target_id, rating, body, author_display_name
    ) values (
      auth.uid(), p_target_type, p_target_id, p_rating, btrim(p_body), display_name
    ) returning * into saved;
  end if;

  insert into public.public_reviews (
    id, target_type, target_id, rating, body, author_display_name,
    version, created_at, updated_at
  ) values (
    saved.id, saved.target_type, saved.target_id, saved.rating, saved.body,
    saved.author_display_name, saved.version, saved.created_at, saved.updated_at
  ) on conflict (id) do update set
    rating = excluded.rating,
    body = excluded.body,
    author_display_name = excluded.author_display_name,
    version = excluded.version,
    updated_at = excluded.updated_at;

  perform private.recalculate_target_rating(p_target_type, p_target_id);
  return to_jsonb(saved) - 'user_id';
end;
$$;

create or replace function public.delete_my_review(
  p_review_id uuid,
  p_expected_version integer
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  existing public.reviews;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot delete reviews';
  end if;
  select * into existing from public.reviews
  where id = p_review_id and user_id = auth.uid() and status = 'published'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Review not found';
  end if;
  if existing.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Review changed concurrently';
  end if;

  update public.reviews
  set status = 'removed_by_author', removed_at = clock_timestamp(),
      version = version + 1, updated_at = clock_timestamp()
  where id = existing.id;
  delete from public.public_reviews where id = existing.id;
  perform private.recalculate_target_rating(existing.target_type, existing.target_id);
end;
$$;

create or replace function public.report_content(
  p_target_type text,
  p_target_id uuid,
  p_reason text,
  p_explanation text default null,
  p_hide_for_me boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  created public.moderation_cases;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot report content';
  end if;
  if p_reason not in ('spam', 'harassment', 'hate', 'dangerous', 'misleading', 'privacy', 'other') then
    raise exception using errcode = '22023', message = 'Invalid report reason';
  end if;
  if (
    select count(*)
    from public.moderation_cases mc
    where mc.reporter_id = auth.uid()
      and mc.created_at >= clock_timestamp() - interval '1 hour'
  ) >= 10 then
    raise exception using errcode = 'P0001', message = 'Report rate limit exceeded';
  end if;
  if (p_target_type = 'review' and not exists (
        select 1 from public.public_reviews where id = p_target_id
      ))
      or (p_target_type = 'spot' and not exists (
        select 1 from public.published_spots where id = p_target_id
      ))
      or p_target_type not in ('review', 'spot') then
    raise exception using errcode = '23503', message = 'Report target is unavailable';
  end if;
  if (p_target_type = 'review' and exists (
        select 1 from public.reviews
        where id = p_target_id and user_id = auth.uid()
      ))
      or (p_target_type = 'spot' and exists (
        select 1 from public.spots
        where id = p_target_id and owner_id = auth.uid()
      )) then
    raise exception using errcode = '22023', message = 'Users cannot report their own content';
  end if;

  insert into public.moderation_cases (
    reporter_id, target_type, target_id, reason, explanation
  ) values (
    auth.uid(), p_target_type, p_target_id, p_reason,
    nullif(btrim(p_explanation), '')
  ) returning * into created;

  if p_hide_for_me then
    insert into public.hidden_content (user_id, target_type, target_id)
    values (auth.uid(), p_target_type, p_target_id)
    on conflict do nothing;
  end if;

  return jsonb_build_object(
    'id', created.id,
    'status', created.status,
    'version', created.version,
    'created_at', created.created_at
  );
end;
$$;

create or replace function public.admin_decide_review_report(
  p_case_id uuid,
  p_decision text,
  p_reason text,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  moderation_case public.moderation_cases;
  target_review public.reviews;
  next_version integer;
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  if p_decision not in ('upheld', 'dismissed', 'escalated')
      or char_length(btrim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'Invalid moderation decision';
  end if;

  select * into moderation_case from public.moderation_cases
  where id = p_case_id for update;
  if not found or moderation_case.target_type <> 'review' then
    raise exception using errcode = 'P0002', message = 'Review report not found';
  end if;
  if moderation_case.status not in ('pending', 'under_review', 'escalated') then
    raise exception using errcode = '22023', message = 'Report is already decided';
  end if;
  if moderation_case.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Report changed concurrently';
  end if;
  next_version := p_expected_version + 1;

  update public.moderation_cases
  set status = p_decision::public.moderation_case_status,
      version = next_version,
      decision_reason = btrim(p_reason),
      decided_by = case when p_decision = 'escalated' then null else auth.uid() end,
      decided_at = case when p_decision = 'escalated' then null else clock_timestamp() end,
      updated_at = clock_timestamp()
  where id = moderation_case.id;

  insert into public.moderation_decisions (
    case_id, decision, reason, actor_id, case_version
  ) values (
    moderation_case.id, p_decision::public.moderation_case_status,
    btrim(p_reason), auth.uid(), next_version
  );

  if p_decision = 'upheld' then
    select * into target_review from public.reviews
    where id = moderation_case.target_id for update;
    if found and target_review.status = 'published' then
      update public.reviews
      set status = 'removed_by_moderation', removed_at = clock_timestamp(),
          version = version + 1, updated_at = clock_timestamp()
      where id = target_review.id;
      delete from public.public_reviews where id = target_review.id;
      perform private.recalculate_target_rating(
        target_review.target_type, target_review.target_id
      );
    end if;
  end if;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason, metadata
  ) values (
    auth.uid(), 'admin.review_report_' || p_decision, 'moderation_case',
    moderation_case.id, btrim(p_reason),
    jsonb_build_object('version', next_version, 'review_id', moderation_case.target_id)
  );

  return jsonb_build_object(
    'case_id', moderation_case.id,
    'status', p_decision,
    'version', next_version
  );
end;
$$;

alter table public.spots enable row level security;
alter table public.spot_revisions enable row level security;
alter table public.spot_moderation_decisions enable row level security;
alter table public.published_spots enable row level security;
alter table public.reviews enable row level security;
alter table public.review_edit_history enable row level security;
alter table public.public_reviews enable row level security;
alter table public.moderation_cases enable row level security;
alter table public.moderation_decisions enable row level security;
alter table public.hidden_content enable row level security;

create policy spots_select_owner on public.spots for select to authenticated
  using (owner_id = auth.uid());
create policy spots_select_admin on public.spots for select to authenticated
  using (private.is_admin());
create policy spot_revisions_select_owner on public.spot_revisions for select to authenticated
  using (exists (
    select 1 from public.spots s where s.id = spot_id and s.owner_id = auth.uid()
  ));
create policy spot_revisions_select_admin on public.spot_revisions for select to authenticated
  using (private.is_admin());
create policy spot_decisions_select_owner on public.spot_moderation_decisions
  for select to authenticated using (exists (
    select 1 from public.spots s where s.id = spot_id and s.owner_id = auth.uid()
  ));
create policy spot_decisions_select_admin on public.spot_moderation_decisions
  for select to authenticated using (private.is_admin());

create policy published_spots_public_read on public.published_spots
  for select to anon, authenticated
  using (not private.is_content_hidden('spot', id));

create policy reviews_select_owner on public.reviews for select to authenticated
  using (user_id = auth.uid());
create policy reviews_select_admin on public.reviews for select to authenticated
  using (private.is_admin());
create policy review_history_select_owner on public.review_edit_history
  for select to authenticated using (exists (
    select 1 from public.reviews r where r.id = review_id and r.user_id = auth.uid()
  ));
create policy review_history_select_admin on public.review_edit_history
  for select to authenticated using (private.is_admin());
create policy public_reviews_public_read on public.public_reviews
  for select to anon, authenticated
  using (not private.is_content_hidden('review', id));
create policy moderation_cases_select_reporter on public.moderation_cases
  for select to authenticated using (reporter_id = auth.uid());
create policy moderation_cases_select_admin on public.moderation_cases
  for select to authenticated using (private.is_admin());
create policy moderation_decisions_select_admin on public.moderation_decisions
  for select to authenticated using (private.is_admin());
create policy hidden_content_select_self on public.hidden_content
  for select to authenticated using (user_id = auth.uid());

revoke all on table public.spots from anon, authenticated;
revoke all on table public.spot_revisions from anon, authenticated;
revoke all on table public.spot_moderation_decisions from anon, authenticated;
revoke all on table public.published_spots from anon, authenticated;
revoke all on table public.reviews from anon, authenticated;
revoke all on table public.review_edit_history from anon, authenticated;
revoke all on table public.public_reviews from anon, authenticated;
revoke all on table public.moderation_cases from anon, authenticated;
revoke all on table public.moderation_decisions from anon, authenticated;
revoke all on table public.hidden_content from anon, authenticated;

grant select on table public.published_spots to anon, authenticated;
grant select on table public.public_reviews to anon, authenticated;
grant select on table public.spots to authenticated;
grant select on table public.spot_revisions to authenticated;
grant select on table public.spot_moderation_decisions to authenticated;
grant select on table public.reviews to authenticated;
grant select on table public.review_edit_history to authenticated;
grant select on table public.moderation_cases to authenticated;
grant select on table public.moderation_decisions to authenticated;
grant select on table public.hidden_content to authenticated;

revoke all on function public.create_spot_draft(
  text, text, text, text, text, text, text, text, text, text,
  double precision, double precision
) from public;
revoke all on function public.submit_spot_revision(uuid, text) from public;
revoke all on function public.delete_spot_draft(uuid) from public;
revoke all on function public.revise_spot(uuid) from public;
revoke all on function public.admin_moderate_spot_revision(uuid, text, text, integer) from public;
revoke all on function public.upsert_review(text, uuid, integer, text, integer) from public;
revoke all on function public.delete_my_review(uuid, integer) from public;
revoke all on function public.report_content(text, uuid, text, text, boolean) from public;
revoke all on function public.admin_decide_review_report(uuid, text, text, integer) from public;

grant execute on function public.create_spot_draft(
  text, text, text, text, text, text, text, text, text, text,
  double precision, double precision
) to authenticated;
grant execute on function public.submit_spot_revision(uuid, text) to authenticated;
grant execute on function public.delete_spot_draft(uuid) to authenticated;
grant execute on function public.revise_spot(uuid) to authenticated;
grant execute on function public.admin_moderate_spot_revision(uuid, text, text, integer) to authenticated;
grant execute on function public.upsert_review(text, uuid, integer, text, integer) to authenticated;
grant execute on function public.delete_my_review(uuid, integer) to authenticated;
grant execute on function public.report_content(text, uuid, text, text, boolean) to authenticated;
grant execute on function public.admin_decide_review_report(uuid, text, text, integer) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'spot-images', 'spot-images', false, 8388608,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy spot_image_insert_owner
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'spot-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.can_use_protected_features()
  );
create policy spot_image_update_owner
  on storage.objects for update to authenticated
  using (
    bucket_id = 'spot-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.can_use_protected_features()
  )
  with check (
    bucket_id = 'spot-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.can_use_protected_features()
  );
create policy spot_image_select_authorized
  on storage.objects for select to anon, authenticated
  using (
    bucket_id = 'spot-images'
    and exists (select 1 from public.published_spots ps where ps.image_path = name)
  );
create policy spot_image_select_owner_admin
  on storage.objects for select to authenticated
  using (
    bucket_id = 'spot-images'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or private.is_admin()
    )
  );
create policy spot_image_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'spot-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

commit;
