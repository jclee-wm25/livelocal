begin;

create table public.saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  spot_id uuid references public.spots(id) on delete cascade,
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  saved_at timestamptz not null default clock_timestamp(),
  constraint saved_place_exactly_one_target check (
    (spot_id is not null)::integer + (restaurant_id is not null)::integer = 1
  )
);

create unique index saved_places_one_spot_per_user
  on public.saved_places(user_id, spot_id) where spot_id is not null;
create unique index saved_places_one_restaurant_per_user
  on public.saved_places(user_id, restaurant_id) where restaurant_id is not null;
create index saved_places_user_recent
  on public.saved_places(user_id, saved_at desc);

create table public.user_discovery_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  location_mode text not null default 'none'
    check (location_mode in ('none', 'manual', 'device')),
  state text,
  city text,
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  version integer not null default 1 check (version > 0),
  updated_at timestamptz not null default clock_timestamp(),
  constraint discovery_preference_coordinates_pair check (
    (latitude is null and longitude is null)
    or (latitude is not null and longitude is not null)
  ),
  constraint manual_location_has_label check (
    location_mode <> 'manual'
    or (
      char_length(btrim(coalesce(state, ''))) between 2 and 80
      and char_length(btrim(coalesce(city, ''))) between 2 and 100
    )
  )
);

create table public.itineraries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 2 and 120),
  origin_label text not null
    check (char_length(btrim(origin_label)) between 2 and 160),
  origin_latitude double precision not null check (origin_latitude between -90 and 90),
  origin_longitude double precision not null check (origin_longitude between -180 and 180),
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  archived_at timestamptz
);

create index itineraries_user_recent
  on public.itineraries(user_id, updated_at desc) where archived_at is null;

create table public.itinerary_items (
  id uuid primary key default gen_random_uuid(),
  itinerary_id uuid not null
    references public.itineraries(id) on delete cascade,
  position integer not null check (position between 1 and 50),
  spot_id uuid references public.spots(id) on delete restrict,
  restaurant_id uuid references public.restaurants(id) on delete restrict,
  note text check (char_length(note) <= 500),
  created_at timestamptz not null default clock_timestamp(),
  constraint itinerary_item_exactly_one_target check (
    (spot_id is not null)::integer + (restaurant_id is not null)::integer = 1
  ),
  unique (itinerary_id, position)
);

create unique index itinerary_items_one_spot
  on public.itinerary_items(itinerary_id, spot_id) where spot_id is not null;
create unique index itinerary_items_one_restaurant
  on public.itinerary_items(itinerary_id, restaurant_id)
  where restaurant_id is not null;

create or replace function private.validate_itinerary_targets(
  p_user_id uuid,
  p_ordered_targets jsonb
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_count integer;
  distinct_count integer;
  valid_count integer;
begin
  if jsonb_typeof(p_ordered_targets) <> 'array' then
    raise exception using errcode = '22023', message = 'Itinerary targets must be an array';
  end if;
  target_count := jsonb_array_length(p_ordered_targets);
  if target_count < 1 or target_count > 50 then
    raise exception using errcode = '22023', message = 'An itinerary requires 1 to 50 stops';
  end if;

  select count(distinct (item->>'type', item->>'id'))
  into distinct_count
  from jsonb_array_elements(p_ordered_targets) item;
  if distinct_count <> target_count then
    raise exception using errcode = '23505', message = 'Itinerary stops must be unique';
  end if;

  select count(*) into valid_count
  from jsonb_array_elements(p_ordered_targets) item
  where (
    item->>'type' = 'spot'
    and (item->>'id') ~* '^[0-9a-f-]{36}$'
    and exists (
      select 1 from public.saved_places saved
      join public.published_spots published on published.id = saved.spot_id
      where saved.user_id = p_user_id
        and saved.spot_id = (item->>'id')::uuid
    )
  ) or (
    item->>'type' = 'restaurant'
    and (item->>'id') ~* '^[0-9a-f-]{36}$'
    and exists (
      select 1 from public.saved_places saved
      join public.published_restaurants published
        on published.id = saved.restaurant_id
      where saved.user_id = p_user_id
        and saved.restaurant_id = (item->>'id')::uuid
    )
  );
  if valid_count <> target_count then
    raise exception using errcode = '42501', message = 'Itinerary contains an unavailable or unsaved target';
  end if;
end;
$$;

revoke all on function private.validate_itinerary_targets(uuid, jsonb)
  from public;

create or replace function public.set_saved_place(
  p_target_type text,
  p_target_id uuid,
  p_saved boolean
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  saved public.saved_places;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot manage saved places';
  end if;
  if p_target_type = 'spot' then
    if not exists (select 1 from public.published_spots where id = p_target_id) then
      raise exception using errcode = 'P0002', message = 'Spot is unavailable';
    end if;
  elsif p_target_type = 'restaurant' then
    if not exists (select 1 from public.published_restaurants where id = p_target_id) then
      raise exception using errcode = 'P0002', message = 'Restaurant is unavailable';
    end if;
  else
    raise exception using errcode = '22023', message = 'Unsupported saved-place target';
  end if;

  if p_saved then
    insert into public.saved_places (user_id, spot_id, restaurant_id)
    values (
      actor,
      case when p_target_type = 'spot' then p_target_id else null end,
      case when p_target_type = 'restaurant' then p_target_id else null end
    ) on conflict do nothing;
  else
    delete from public.saved_places
    where user_id = actor
      and (
        (p_target_type = 'spot' and spot_id = p_target_id)
        or (p_target_type = 'restaurant' and restaurant_id = p_target_id)
      );
  end if;

  select * into saved from public.saved_places
  where user_id = actor
    and (
      (p_target_type = 'spot' and spot_id = p_target_id)
      or (p_target_type = 'restaurant' and restaurant_id = p_target_id)
    );
  return jsonb_build_object(
    'target_type', p_target_type,
    'target_id', p_target_id,
    'saved', found,
    'saved_at', saved.saved_at
  );
end;
$$;

create or replace function public.update_my_discovery_location(
  p_location_mode text,
  p_state text,
  p_city text,
  p_latitude double precision,
  p_longitude double precision,
  p_expected_version integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare saved public.user_discovery_preferences;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot update preferences';
  end if;
  if p_location_mode not in ('none', 'manual', 'device')
      or ((p_latitude is null) <> (p_longitude is null))
      or (p_location_mode = 'manual' and (
        char_length(btrim(coalesce(p_state, ''))) < 2
        or char_length(btrim(coalesce(p_city, ''))) < 2
        or p_latitude is null
      )) then
    raise exception using errcode = '22023', message = 'Invalid discovery location';
  end if;

  insert into public.user_discovery_preferences (
    user_id, location_mode, state, city, latitude, longitude
  ) values (
    auth.uid(), p_location_mode,
    case when p_location_mode = 'none' then null else nullif(btrim(p_state), '') end,
    case when p_location_mode = 'none' then null else nullif(btrim(p_city), '') end,
    case when p_location_mode = 'none' then null else p_latitude end,
    case when p_location_mode = 'none' then null else p_longitude end
  ) on conflict (user_id) do update set
    location_mode = excluded.location_mode,
    state = excluded.state,
    city = excluded.city,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    version = public.user_discovery_preferences.version + 1,
    updated_at = clock_timestamp()
  where p_expected_version is null
    or public.user_discovery_preferences.version = p_expected_version
  returning * into saved;
  if not found then
    raise exception using errcode = '40001', message = 'Location preference changed concurrently';
  end if;
  return to_jsonb(saved) - 'user_id';
end;
$$;

create or replace function private.insert_itinerary_items(
  p_itinerary_id uuid,
  p_ordered_targets jsonb
)
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  insert into public.itinerary_items (
    itinerary_id, position, spot_id, restaurant_id
  )
  select
    p_itinerary_id,
    item.ordinality::integer,
    case when item.value->>'type' = 'spot'
      then (item.value->>'id')::uuid else null end,
    case when item.value->>'type' = 'restaurant'
      then (item.value->>'id')::uuid else null end
  from jsonb_array_elements(p_ordered_targets) with ordinality item(value, ordinality);
$$;

revoke all on function private.insert_itinerary_items(uuid, jsonb) from public;

create or replace function public.create_itinerary_from_saved(
  p_title text,
  p_origin_label text,
  p_origin_latitude double precision,
  p_origin_longitude double precision,
  p_ordered_targets jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare created public.itineraries;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot create itineraries';
  end if;
  if char_length(btrim(p_title)) not between 2 and 120
      or char_length(btrim(p_origin_label)) not between 2 and 160
      or p_origin_latitude not between -90 and 90
      or p_origin_longitude not between -180 and 180 then
    raise exception using errcode = '22023', message = 'Invalid itinerary details';
  end if;
  perform private.validate_itinerary_targets(auth.uid(), p_ordered_targets);
  insert into public.itineraries (
    user_id, title, origin_label, origin_latitude, origin_longitude
  ) values (
    auth.uid(), btrim(p_title), btrim(p_origin_label),
    p_origin_latitude, p_origin_longitude
  ) returning * into created;
  perform private.insert_itinerary_items(created.id, p_ordered_targets);
  return jsonb_build_object(
    'id', created.id, 'title', created.title, 'version', created.version,
    'created_at', created.created_at
  );
end;
$$;

create or replace function public.replace_itinerary_order(
  p_itinerary_id uuid,
  p_ordered_targets jsonb,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare existing public.itineraries;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot update itineraries';
  end if;
  select * into existing from public.itineraries
  where id = p_itinerary_id and user_id = auth.uid() and archived_at is null
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Itinerary not found';
  end if;
  if existing.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Itinerary changed concurrently';
  end if;
  perform private.validate_itinerary_targets(auth.uid(), p_ordered_targets);
  delete from public.itinerary_items where itinerary_id = existing.id;
  perform private.insert_itinerary_items(existing.id, p_ordered_targets);
  update public.itineraries set version = version + 1,
    updated_at = clock_timestamp()
  where id = existing.id returning * into existing;
  return jsonb_build_object(
    'id', existing.id, 'version', existing.version,
    'updated_at', existing.updated_at
  );
end;
$$;

create or replace function public.archive_itinerary(
  p_itinerary_id uuid,
  p_expected_version integer
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot archive itineraries';
  end if;
  update public.itineraries set archived_at = clock_timestamp(),
    version = version + 1, updated_at = clock_timestamp()
  where id = p_itinerary_id and user_id = auth.uid()
    and archived_at is null and version = p_expected_version;
  if not found then
    raise exception using errcode = '40001', message = 'Itinerary changed concurrently';
  end if;
end;
$$;

alter table public.saved_places enable row level security;
alter table public.user_discovery_preferences enable row level security;
alter table public.itineraries enable row level security;
alter table public.itinerary_items enable row level security;

create policy saved_places_owner_select on public.saved_places
  for select to authenticated
  using (user_id = auth.uid() and private.can_use_protected_features());
create policy discovery_preferences_owner_select
  on public.user_discovery_preferences for select to authenticated
  using (user_id = auth.uid() and private.can_use_protected_features());
create policy itineraries_owner_select on public.itineraries
  for select to authenticated
  using (user_id = auth.uid() and private.can_use_protected_features());
create policy itinerary_items_owner_select on public.itinerary_items
  for select to authenticated using (exists (
    select 1 from public.itineraries itinerary
    where itinerary.id = public.itinerary_items.itinerary_id
      and itinerary.user_id = auth.uid()
      and private.can_use_protected_features()
  ));

revoke all on table public.saved_places from anon, authenticated;
revoke all on table public.user_discovery_preferences from anon, authenticated;
revoke all on table public.itineraries from anon, authenticated;
revoke all on table public.itinerary_items from anon, authenticated;
grant select on table public.saved_places to authenticated;
grant select on table public.user_discovery_preferences to authenticated;
grant select on table public.itineraries to authenticated;
grant select on table public.itinerary_items to authenticated;

revoke all on function public.set_saved_place(text, uuid, boolean) from public;
revoke all on function public.update_my_discovery_location(
  text, text, text, double precision, double precision, integer
) from public;
revoke all on function public.create_itinerary_from_saved(
  text, text, double precision, double precision, jsonb
) from public;
revoke all on function public.replace_itinerary_order(uuid, jsonb, integer)
  from public;
revoke all on function public.archive_itinerary(uuid, integer) from public;

grant execute on function public.set_saved_place(text, uuid, boolean)
  to authenticated;
grant execute on function public.update_my_discovery_location(
  text, text, text, double precision, double precision, integer
) to authenticated;
grant execute on function public.create_itinerary_from_saved(
  text, text, double precision, double precision, jsonb
) to authenticated;
grant execute on function public.replace_itinerary_order(uuid, jsonb, integer)
  to authenticated;
grant execute on function public.archive_itinerary(uuid, integer)
  to authenticated;

commit;
