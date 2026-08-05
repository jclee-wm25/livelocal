begin;

create or replace function public.list_my_spot_submissions()
returns table (
  spot_id uuid,
  revision_id uuid,
  moderation_version integer,
  status public.content_revision_status,
  name text,
  category text,
  description text,
  state text,
  city text,
  address text,
  price_range text,
  best_time text,
  things_to_do text,
  image_path text,
  latitude double precision,
  longitude double precision,
  decision_reason text,
  has_approved_revision boolean,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot manage spot submissions';
  end if;

  return query
  select
    entity.id,
    revision.id,
    entity.moderation_version,
    revision.status,
    revision.name,
    revision.category,
    revision.description,
    revision.state,
    revision.city,
    revision.address,
    revision.price_range,
    revision.best_time,
    revision.things_to_do,
    revision.image_path,
    revision.latitude,
    revision.longitude,
    decision.reason,
    entity.approved_revision_id is not null,
    revision.updated_at
  from public.spots entity
  join public.spot_revisions revision
    on revision.id = entity.current_revision_id
  left join lateral (
    select moderation.reason
    from public.spot_moderation_decisions moderation
    where moderation.revision_id = revision.id
    order by moderation.created_at desc
    limit 1
  ) decision on true
  where entity.owner_id = auth.uid()
  order by revision.updated_at desc, entity.id;
end;
$$;

create or replace function public.save_spot_revision_draft(
  p_source_revision_id uuid,
  p_name text,
  p_category text,
  p_description text,
  p_state text,
  p_city text,
  p_address text,
  p_price_range text,
  p_best_time text,
  p_things_to_do text,
  p_image_path text,
  p_latitude double precision,
  p_longitude double precision
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
declare
  entity public.spots;
  source public.spot_revisions;
  saved public.spot_revisions;
  next_number integer;
  selected_image_path text;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot revise spots';
  end if;

  select * into entity
  from public.spots
  where owner_id = auth.uid()
    and current_revision_id = p_source_revision_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Current owned spot revision not found';
  end if;

  select * into source
  from public.spot_revisions
  where id = p_source_revision_id
  for update;

  if source.status not in (
    'draft', 'submitted', 'under_review', 'approved', 'rejected', 'withdrawn'
  ) then
    raise exception using errcode = '22023', message = 'Spot revision cannot be edited';
  end if;

  selected_image_path := coalesce(p_image_path, source.image_path);
  if selected_image_path is null
      or selected_image_path !~ ('^' || auth.uid()::text || '/[A-Za-z0-9_-]+\\.(jpg|png|webp)$')
      or not exists (
        select 1 from storage.objects object
        where object.bucket_id = 'spot-images'
          and object.name = selected_image_path
      ) then
    raise exception using errcode = '22023', message = 'An uploaded owned spot image is required';
  end if;

  if source.status = 'draft' then
    update public.spot_revisions set
      name = btrim(p_name),
      category = btrim(p_category),
      description = btrim(p_description),
      state = btrim(p_state),
      city = btrim(p_city),
      address = btrim(p_address),
      price_range = p_price_range,
      best_time = btrim(p_best_time),
      things_to_do = btrim(p_things_to_do),
      image_path = selected_image_path,
      image_rights_confirmed_at = null,
      latitude = p_latitude,
      longitude = p_longitude,
      duplicate_override_reason = null,
      updated_at = clock_timestamp()
    where id = source.id
    returning * into saved;
  else
    if source.status in ('submitted', 'under_review') then
      update public.spot_revisions
      set status = 'withdrawn', updated_at = clock_timestamp()
      where id = source.id;
    end if;

    select coalesce(max(revision_number), 0) + 1 into next_number
    from public.spot_revisions
    where spot_id = entity.id;

    insert into public.spot_revisions (
      spot_id, revision_number, author_id, name, category, description,
      state, city, address, price_range, best_time, things_to_do,
      image_path, latitude, longitude
    ) values (
      entity.id, next_number, auth.uid(), btrim(p_name), btrim(p_category),
      btrim(p_description), btrim(p_state), btrim(p_city), btrim(p_address),
      p_price_range, btrim(p_best_time), btrim(p_things_to_do),
      selected_image_path, p_latitude, p_longitude
    ) returning * into saved;

    update public.spots
    set current_revision_id = saved.id
    where id = entity.id;
  end if;

  if source.status = 'draft'
      and source.image_path is distinct from saved.image_path
      and source.image_path is not null
      and not exists (
        select 1 from public.spot_revisions remaining
        where remaining.image_path = source.image_path
      ) then
    delete from storage.objects
    where bucket_id = 'spot-images' and name = source.image_path;
  end if;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, metadata
  ) values (
    auth.uid(), 'spot.revision_draft_saved', 'spot', entity.id,
    jsonb_build_object(
      'source_revision_id', source.id,
      'revision_id', saved.id,
      'revision_number', saved.revision_number
    )
  );

  return jsonb_build_object(
    'spot_id', entity.id,
    'revision_id', saved.id,
    'image_path', saved.image_path,
    'status', 'draft',
    'probable_duplicates', private.probable_spot_duplicates(
      saved.name, saved.address, saved.latitude, saved.longitude, entity.id
    )
  );
end;
$$;

create or replace function public.withdraw_my_spot_revision(p_revision_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  entity public.spots;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot withdraw spot submissions';
  end if;

  select * into entity
  from public.spots
  where owner_id = auth.uid()
    and current_revision_id = p_revision_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Current owned spot revision not found';
  end if;

  update public.spot_revisions
  set status = 'withdrawn', updated_at = clock_timestamp()
  where id = p_revision_id and status in ('submitted', 'under_review');
  if not found then
    raise exception using errcode = '22023', message = 'Spot revision is not awaiting review';
  end if;

  if entity.approved_revision_id is not null then
    update public.spots
    set current_revision_id = approved_revision_id
    where id = entity.id;
  end if;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, metadata
  ) values (
    auth.uid(), 'spot.revision_withdrawn', 'spot', entity.id,
    jsonb_build_object('revision_id', p_revision_id)
  );
end;
$$;

create or replace function public.delete_spot_draft(p_revision_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
declare
  entity public.spots;
  revision public.spot_revisions;
  removed_image_path text;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot discard spot drafts';
  end if;

  select * into entity
  from public.spots
  where owner_id = auth.uid()
    and current_revision_id = p_revision_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Draft not found';
  end if;

  select * into revision
  from public.spot_revisions
  where id = p_revision_id and status = 'draft'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Draft not found';
  end if;
  removed_image_path := revision.image_path;

  if entity.approved_revision_id is null then
    delete from public.spots where id = entity.id;
  else
    update public.spots
    set current_revision_id = approved_revision_id
    where id = entity.id;
    delete from public.spot_revisions where id = revision.id;
  end if;

  if removed_image_path is not null
      and not exists (
        select 1 from public.spot_revisions remaining
        where remaining.image_path = removed_image_path
      ) then
    delete from storage.objects
    where bucket_id = 'spot-images' and name = removed_image_path;
  end if;
end;
$$;

create or replace function public.list_my_restaurant_submissions()
returns table (
  restaurant_id uuid,
  revision_id uuid,
  moderation_version integer,
  status public.content_revision_status,
  name text,
  address text,
  state text,
  city text,
  cuisine_type text,
  price_range text,
  reviewed_dishes text,
  social_media_url text,
  cover_image_path text,
  latitude double precision,
  longitude double precision,
  decision_reason text,
  has_approved_revision boolean,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'influencer' then
    raise exception using errcode = '42501', message = 'Approved creator role required';
  end if;

  return query
  select
    entity.id,
    revision.id,
    entity.moderation_version,
    revision.status,
    revision.name,
    revision.address,
    revision.state,
    revision.city,
    revision.cuisine_type,
    revision.price_range,
    revision.reviewed_dishes,
    revision.social_media_url,
    revision.cover_image_path,
    revision.latitude,
    revision.longitude,
    decision.reason,
    entity.approved_revision_id is not null,
    revision.updated_at
  from public.restaurants entity
  join public.restaurant_revisions revision
    on revision.id = entity.current_revision_id
  left join lateral (
    select moderation.reason
    from public.restaurant_moderation_decisions moderation
    where moderation.revision_id = revision.id
    order by moderation.created_at desc
    limit 1
  ) decision on true
  where entity.owner_id = auth.uid()
  order by revision.updated_at desc, entity.id;
end;
$$;

create or replace function public.save_restaurant_revision_draft(
  p_source_revision_id uuid,
  p_name text,
  p_address text,
  p_state text,
  p_city text,
  p_cuisine_type text,
  p_price_range text,
  p_reviewed_dishes text,
  p_social_media_url text,
  p_cover_image_path text,
  p_latitude double precision,
  p_longitude double precision
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
declare
  entity public.restaurants;
  source public.restaurant_revisions;
  saved public.restaurant_revisions;
  next_number integer;
  selected_image_path text;
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'influencer' then
    raise exception using errcode = '42501', message = 'Approved creator role required';
  end if;
  if not private.is_supported_social_url(p_social_media_url, null) then
    raise exception using errcode = '22023', message = 'Unsupported social URL';
  end if;

  select * into entity
  from public.restaurants
  where owner_id = auth.uid()
    and current_revision_id = p_source_revision_id
    and ownership_status = 'creator_owned'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Current owned restaurant revision not found';
  end if;

  select * into source
  from public.restaurant_revisions
  where id = p_source_revision_id
  for update;
  if source.status not in (
    'draft', 'submitted', 'under_review', 'approved', 'rejected', 'withdrawn'
  ) then
    raise exception using errcode = '22023', message = 'Restaurant revision cannot be edited';
  end if;

  selected_image_path := coalesce(p_cover_image_path, source.cover_image_path);
  if selected_image_path is null
      or selected_image_path !~ ('^' || auth.uid()::text || '/[A-Za-z0-9_-]+\\.(jpg|png|webp)$')
      or not exists (
        select 1 from storage.objects object
        where object.bucket_id = 'restaurant-images'
          and object.name = selected_image_path
      ) then
    raise exception using errcode = '22023', message = 'An uploaded owned restaurant image is required';
  end if;

  if source.status = 'draft' then
    update public.restaurant_revisions set
      name = btrim(p_name),
      address = btrim(p_address),
      state = btrim(p_state),
      city = btrim(p_city),
      cuisine_type = btrim(p_cuisine_type),
      price_range = p_price_range,
      reviewed_dishes = btrim(p_reviewed_dishes),
      social_media_url = btrim(p_social_media_url),
      cover_image_path = selected_image_path,
      latitude = p_latitude,
      longitude = p_longitude,
      duplicate_override_reason = null,
      updated_at = clock_timestamp()
    where id = source.id
    returning * into saved;
  else
    if source.status in ('submitted', 'under_review') then
      update public.restaurant_revisions
      set status = 'withdrawn', updated_at = clock_timestamp()
      where id = source.id;
    end if;

    select coalesce(max(revision_number), 0) + 1 into next_number
    from public.restaurant_revisions
    where restaurant_id = entity.id;

    insert into public.restaurant_revisions (
      restaurant_id, revision_number, author_id, name, address, state, city,
      cuisine_type, price_range, reviewed_dishes, social_media_url,
      cover_image_path, latitude, longitude
    ) values (
      entity.id, next_number, auth.uid(), btrim(p_name), btrim(p_address),
      btrim(p_state), btrim(p_city), btrim(p_cuisine_type), p_price_range,
      btrim(p_reviewed_dishes), btrim(p_social_media_url), selected_image_path,
      p_latitude, p_longitude
    ) returning * into saved;

    update public.restaurants
    set current_revision_id = saved.id
    where id = entity.id;
  end if;

  if source.status = 'draft'
      and source.cover_image_path is distinct from saved.cover_image_path
      and source.cover_image_path is not null
      and not exists (
        select 1 from public.restaurant_revisions remaining
        where remaining.cover_image_path = source.cover_image_path
      ) then
    delete from storage.objects
    where bucket_id = 'restaurant-images' and name = source.cover_image_path;
  end if;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, metadata
  ) values (
    auth.uid(), 'restaurant.revision_draft_saved', 'restaurant', entity.id,
    jsonb_build_object(
      'source_revision_id', source.id,
      'revision_id', saved.id,
      'revision_number', saved.revision_number
    )
  );

  return jsonb_build_object(
    'restaurant_id', entity.id,
    'revision_id', saved.id,
    'image_path', saved.cover_image_path,
    'status', 'draft',
    'probable_duplicates', private.probable_restaurant_duplicates(
      saved.name, saved.address, saved.latitude, saved.longitude, entity.id
    )
  );
end;
$$;

create or replace function public.withdraw_my_restaurant_revision(p_revision_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  entity public.restaurants;
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'influencer' then
    raise exception using errcode = '42501', message = 'Approved creator role required';
  end if;

  select * into entity
  from public.restaurants
  where owner_id = auth.uid()
    and current_revision_id = p_revision_id
    and ownership_status = 'creator_owned'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Current owned restaurant revision not found';
  end if;

  update public.restaurant_revisions
  set status = 'withdrawn', updated_at = clock_timestamp()
  where id = p_revision_id and status in ('submitted', 'under_review');
  if not found then
    raise exception using errcode = '22023', message = 'Restaurant revision is not awaiting review';
  end if;

  if entity.approved_revision_id is not null then
    update public.restaurants
    set current_revision_id = approved_revision_id
    where id = entity.id;
  end if;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, metadata
  ) values (
    auth.uid(), 'restaurant.revision_withdrawn', 'restaurant', entity.id,
    jsonb_build_object('revision_id', p_revision_id)
  );
end;
$$;

create or replace function public.submit_restaurant_revision(
  p_revision_id uuid,
  p_duplicate_override_reason text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
declare
  revision public.restaurant_revisions;
  duplicates jsonb;
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'influencer' then
    raise exception using errcode = '42501', message = 'Approved creator role required';
  end if;
  select candidate.* into revision
  from public.restaurant_revisions candidate
  join public.restaurants entity on entity.id = candidate.restaurant_id
  where candidate.id = p_revision_id
    and entity.owner_id = auth.uid()
    and entity.current_revision_id = candidate.id
  for update of candidate;
  if not found or revision.status <> 'draft' then
    raise exception using errcode = 'P0002', message = 'Restaurant draft not found';
  end if;
  if revision.cover_image_path is null or not exists (
    select 1 from storage.objects object
    where object.bucket_id = 'restaurant-images'
      and object.name = revision.cover_image_path
  ) then
    raise exception using errcode = '22023', message = 'An uploaded restaurant image is required';
  end if;

  duplicates := private.probable_restaurant_duplicates(
    revision.name, revision.address, revision.latitude, revision.longitude,
    revision.restaurant_id
  );
  if jsonb_array_length(duplicates) > 0
      and char_length(btrim(coalesce(p_duplicate_override_reason, ''))) < 10 then
    raise exception using errcode = '23505',
      message = 'Probable duplicate requires justified override',
      detail = duplicates::text;
  end if;

  update public.restaurant_revisions
  set status = 'submitted', submitted_at = clock_timestamp(),
      duplicate_override_reason = nullif(btrim(p_duplicate_override_reason), ''),
      updated_at = clock_timestamp()
  where id = revision.id;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, metadata
  ) values (
    auth.uid(), 'restaurant.revision_submitted', 'restaurant',
    revision.restaurant_id, jsonb_build_object('revision_id', revision.id)
  );
end;
$$;

create or replace function public.delete_restaurant_draft(p_revision_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
declare
  entity public.restaurants;
  revision public.restaurant_revisions;
  removed_image_path text;
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'influencer' then
    raise exception using errcode = '42501', message = 'Approved creator role required';
  end if;

  select * into entity
  from public.restaurants
  where owner_id = auth.uid()
    and current_revision_id = p_revision_id
    and ownership_status = 'creator_owned'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Draft not found';
  end if;

  select * into revision
  from public.restaurant_revisions
  where id = p_revision_id and status = 'draft'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Draft not found';
  end if;
  removed_image_path := revision.cover_image_path;

  if entity.approved_revision_id is null then
    delete from public.restaurants where id = entity.id;
  else
    update public.restaurants
    set current_revision_id = approved_revision_id
    where id = entity.id;
    delete from public.restaurant_revisions where id = revision.id;
  end if;

  if removed_image_path is not null
      and not exists (
        select 1 from public.restaurant_revisions remaining
        where remaining.cover_image_path = removed_image_path
      ) then
    delete from storage.objects
    where bucket_id = 'restaurant-images' and name = removed_image_path;
  end if;
end;
$$;

revoke all on function public.list_my_spot_submissions() from public;
revoke all on function public.withdraw_my_spot_revision(uuid) from public;
revoke all on function public.save_spot_revision_draft(
  uuid,text,text,text,text,text,text,text,text,text,text,double precision,double precision
) from public;
revoke all on function public.list_my_restaurant_submissions() from public;
revoke all on function public.withdraw_my_restaurant_revision(uuid) from public;
revoke all on function public.save_restaurant_revision_draft(
  uuid,text,text,text,text,text,text,text,text,text,double precision,double precision
) from public;

grant execute on function public.list_my_spot_submissions() to authenticated;
grant execute on function public.withdraw_my_spot_revision(uuid) to authenticated;
grant execute on function public.save_spot_revision_draft(
  uuid,text,text,text,text,text,text,text,text,text,text,double precision,double precision
) to authenticated;
grant execute on function public.list_my_restaurant_submissions() to authenticated;
grant execute on function public.withdraw_my_restaurant_revision(uuid) to authenticated;
grant execute on function public.save_restaurant_revision_draft(
  uuid,text,text,text,text,text,text,text,text,text,double precision,double precision
) to authenticated;

commit;
