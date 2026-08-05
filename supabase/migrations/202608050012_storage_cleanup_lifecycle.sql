begin;

-- Storage metadata is read-only application state. Physical objects are
-- removed or re-homed by the storage-cleanup Edge Function through the
-- Storage API, then acknowledged through the service-only RPCs below.
create table private.storage_cleanup_jobs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  bucket_id text not null
    check (bucket_id in ('avatars', 'spot-images', 'restaurant-images')),
  source_path text not null check (char_length(source_path) between 3 and 1024),
  action text not null check (action in ('delete', 'rehome')),
  destination_path text,
  stage text not null check (
    stage in (
      'delete_object', 'rehome_copy', 'rehome_remove', 'rehome_discard'
    )
  ),
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'failed', 'completed')),
  reason text not null check (char_length(reason) between 3 and 160),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default clock_timestamp(),
  locked_at timestamptz,
  lock_token uuid,
  last_error text check (char_length(last_error) <= 1000),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  constraint storage_cleanup_rehome_destination check (
    (action = 'delete' and destination_path is null)
    or (action = 'rehome' and destination_path is not null)
  ),
  constraint storage_cleanup_lock_pair check (
    (status = 'processing' and locked_at is not null and lock_token is not null)
    or (status <> 'processing' and locked_at is null and lock_token is null)
  ),
  constraint storage_cleanup_completion_time check (
    (status = 'completed' and completed_at is not null)
    or (status <> 'completed' and completed_at is null)
  )
);

create unique index storage_cleanup_one_active_source
  on private.storage_cleanup_jobs(bucket_id, source_path)
  where status in ('pending', 'processing', 'failed');
create index storage_cleanup_claim_order
  on private.storage_cleanup_jobs(next_attempt_at, created_at)
  where status in ('pending', 'processing', 'failed');
create index storage_cleanup_owner_gate
  on private.storage_cleanup_jobs(owner_id, status);

revoke all on table private.storage_cleanup_jobs from public, anon, authenticated;

create or replace function private.storage_path_owner(p_path text)
returns uuid
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare first_segment text;
begin
  first_segment := split_part(coalesce(p_path, ''), '/', 1);
  if first_segment ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    return first_segment::uuid;
  end if;
  return null;
end;
$$;

create or replace function private.enqueue_storage_cleanup(
  p_owner_id uuid,
  p_bucket_id text,
  p_source_path text,
  p_action text,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, private, auth, storage
as $$
declare
  job_id uuid := gen_random_uuid();
  stored_owner uuid;
  destination text;
  existing_id uuid;
  extension text;
begin
  if p_bucket_id not in ('avatars', 'spot-images', 'restaurant-images')
      or p_action not in ('delete', 'rehome')
      or char_length(coalesce(p_source_path, '')) < 3 then
    raise exception using errcode = '22023', message = 'Invalid storage cleanup request';
  end if;

  if not exists (
    select 1 from storage.objects object
    where object.bucket_id = p_bucket_id and object.name = p_source_path
  ) then
    return null;
  end if;

  select p_owner_id into stored_owner
  where exists (select 1 from auth.users where id = p_owner_id);

  if p_action = 'rehome' then
    extension := lower(substring(p_source_path from '(\.[A-Za-z0-9]+)$'));
    if extension not in ('.jpg', '.jpeg', '.png', '.webp') then
      raise exception using errcode = '22023', message = 'Unsupported retained object type';
    end if;
    destination := 'retained/' || job_id::text || extension;
  end if;

  insert into private.storage_cleanup_jobs (
    id, owner_id, bucket_id, source_path, action, destination_path, stage,
    reason
  ) values (
    job_id, stored_owner, p_bucket_id, p_source_path, p_action, destination,
    case when p_action = 'rehome' then 'rehome_copy' else 'delete_object' end,
    p_reason
  )
  on conflict (bucket_id, source_path)
    where status in ('pending', 'processing', 'failed')
    do nothing
  returning id into existing_id;

  if existing_id is not null then
    return existing_id;
  end if;

  select id into existing_id
  from private.storage_cleanup_jobs
  where bucket_id = p_bucket_id
    and source_path = p_source_path
    and status in ('pending', 'processing', 'failed')
  order by created_at desc
  limit 1;
  return existing_id;
end;
$$;

revoke all on function private.storage_path_owner(text) from public;
revoke all on function private.enqueue_storage_cleanup(uuid,text,text,text,text)
  from public;

create or replace function private.queue_removed_profile_avatar()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
begin
  if old.avatar_path is null then
    return null;
  elsif tg_op = 'DELETE' then
    perform private.enqueue_storage_cleanup(
      old.id, 'avatars', old.avatar_path, 'delete', 'profile_avatar_replaced'
    );
  elsif old.avatar_path is distinct from new.avatar_path then
    perform private.enqueue_storage_cleanup(
      old.id, 'avatars', old.avatar_path, 'delete', 'profile_avatar_replaced'
    );
  end if;
  return null;
end;
$$;

create or replace function private.queue_removed_spot_image()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
begin
  if old.image_path is null then
    return null;
  elsif tg_op = 'DELETE' and not exists (
    select 1 from public.spot_revisions remaining
    where remaining.image_path = old.image_path
  ) then
    perform private.enqueue_storage_cleanup(
      coalesce(old.author_id, private.storage_path_owner(old.image_path)),
      'spot-images', old.image_path, 'delete', 'spot_revision_image_unreferenced'
    );
  elsif tg_op = 'UPDATE'
      and old.image_path is distinct from new.image_path
      and not exists (
        select 1 from public.spot_revisions remaining
        where remaining.image_path = old.image_path
      ) then
    perform private.enqueue_storage_cleanup(
      coalesce(old.author_id, private.storage_path_owner(old.image_path)),
      'spot-images', old.image_path, 'delete', 'spot_revision_image_unreferenced'
    );
  end if;
  return null;
end;
$$;

create or replace function private.queue_removed_restaurant_image()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
begin
  if old.cover_image_path is null then
    return null;
  elsif tg_op = 'DELETE' and not exists (
    select 1 from public.restaurant_revisions remaining
    where remaining.cover_image_path = old.cover_image_path
  ) then
    perform private.enqueue_storage_cleanup(
      coalesce(
        old.author_id,
        private.storage_path_owner(old.cover_image_path)
      ),
      'restaurant-images', old.cover_image_path, 'delete',
      'restaurant_revision_image_unreferenced'
    );
  elsif tg_op = 'UPDATE'
      and old.cover_image_path is distinct from new.cover_image_path
      and not exists (
        select 1 from public.restaurant_revisions remaining
        where remaining.cover_image_path = old.cover_image_path
      ) then
    perform private.enqueue_storage_cleanup(
      coalesce(
        old.author_id,
        private.storage_path_owner(old.cover_image_path)
      ),
      'restaurant-images', old.cover_image_path, 'delete',
      'restaurant_revision_image_unreferenced'
    );
  end if;
  return null;
end;
$$;

create trigger queue_profile_avatar_cleanup
  after update of avatar_path or delete on public.profiles
  for each row execute function private.queue_removed_profile_avatar();
create trigger queue_spot_image_cleanup
  after update of image_path or delete on public.spot_revisions
  for each row execute function private.queue_removed_spot_image();
create trigger queue_restaurant_image_cleanup
  after update of cover_image_path or delete on public.restaurant_revisions
  for each row execute function private.queue_removed_restaurant_image();

revoke all on function private.queue_removed_profile_avatar() from public;
revoke all on function private.queue_removed_spot_image() from public;
revoke all on function private.queue_removed_restaurant_image() from public;

-- Replace migration-011 function bodies as part of the forward migration too.
-- This is required for databases that applied 011 before the cleanup queue
-- existed; editing the historical source file alone would not update them.
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
      or selected_image_path !~ ('^' || auth.uid()::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$')
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

create or replace function public.delete_spot_draft(p_revision_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
declare
  entity public.spots;
  revision public.spot_revisions;
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

  if entity.approved_revision_id is null then
    delete from public.spots where id = entity.id;
  else
    update public.spots
    set current_revision_id = approved_revision_id
    where id = entity.id;
    delete from public.spot_revisions where id = revision.id;
  end if;
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
      or selected_image_path !~ ('^' || auth.uid()::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$')
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

create or replace function public.delete_restaurant_draft(p_revision_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
declare
  entity public.restaurants;
  revision public.restaurant_revisions;
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

  if entity.approved_revision_id is null then
    delete from public.restaurants where id = entity.id;
  else
    update public.restaurants
    set current_revision_id = approved_revision_id
    where id = entity.id;
    delete from public.restaurant_revisions where id = revision.id;
  end if;
end;
$$;

create or replace function private.enqueue_account_storage_cleanup(
  p_user_id uuid
)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
declare
  object_record record;
  selected_action text;
  queued integer := 0;
begin
  for object_record in
    select object.bucket_id, object.name
    from storage.objects object
    where object.owner_id = p_user_id::text
      and object.bucket_id in ('avatars', 'spot-images', 'restaurant-images')
    order by object.bucket_id, object.name
  loop
    selected_action := case
      when object_record.bucket_id = 'spot-images' and exists (
        select 1 from public.published_spots published
        where published.image_path = object_record.name
      ) then 'rehome'
      when object_record.bucket_id = 'restaurant-images' and exists (
        select 1 from public.published_restaurants published
        where published.cover_image_path = object_record.name
      ) then 'rehome'
      else 'delete'
    end;

    if private.enqueue_storage_cleanup(
      p_user_id, object_record.bucket_id, object_record.name,
      selected_action, 'account_deletion'
    ) is not null then
      queued := queued + 1;
    end if;
  end loop;
  return queued;
end;
$$;

revoke all on function private.enqueue_account_storage_cleanup(uuid) from public;

create or replace function public.claim_storage_cleanup_jobs(
  p_limit integer default 25
)
returns table (
  id uuid,
  bucket_id text,
  source_path text,
  action text,
  destination_path text,
  stage text,
  lock_token uuid
)
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role'
      and current_user not in ('postgres', 'supabase_admin') then
    raise exception using errcode = '42501', message = 'Service role required';
  end if;
  if p_limit < 1 or p_limit > 100 then
    raise exception using errcode = '22023', message = 'Cleanup batch size must be between 1 and 100';
  end if;

  return query
  with candidates as (
    select job.id
    from private.storage_cleanup_jobs job
    where (
        job.status in ('pending', 'failed')
        and job.next_attempt_at <= clock_timestamp()
      ) or (
        job.status = 'processing'
        and job.locked_at < clock_timestamp() - interval '10 minutes'
      )
    order by job.next_attempt_at, job.created_at
    limit p_limit
    for update skip locked
  ), claimed as (
    update private.storage_cleanup_jobs job
    set status = 'processing',
        attempt_count = job.attempt_count + 1,
        locked_at = clock_timestamp(),
        lock_token = gen_random_uuid(),
        last_error = null,
        updated_at = clock_timestamp()
    from candidates
    where job.id = candidates.id
    returning job.*
  )
  select claimed.id, claimed.bucket_id, claimed.source_path, claimed.action,
    claimed.destination_path, claimed.stage, claimed.lock_token
  from claimed;
end;
$$;

create or replace function public.activate_storage_rehome_job(
  p_job_id uuid,
  p_lock_token uuid
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
declare job private.storage_cleanup_jobs;
declare retained_reference boolean := false;
begin
  if coalesce(auth.role(), '') <> 'service_role'
      and current_user not in ('postgres', 'supabase_admin') then
    raise exception using errcode = '42501', message = 'Service role required';
  end if;

  select * into job from private.storage_cleanup_jobs
  where id = p_job_id and lock_token = p_lock_token
    and status = 'processing' and action = 'rehome'
    and stage = 'rehome_copy'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Claimed rehome job not found';
  end if;
  if not exists (
    select 1 from storage.objects object
    where object.bucket_id = job.bucket_id
      and object.name = job.destination_path
  ) then
    raise exception using errcode = '22023', message = 'Retained object copy is missing';
  end if;

  if job.bucket_id = 'spot-images' then
    retained_reference := exists (
      select 1 from public.published_spots where image_path = job.source_path
    );
    if retained_reference then
      update public.spot_revisions set image_path = job.destination_path,
        updated_at = clock_timestamp()
      where image_path = job.source_path;
      update public.published_spots set image_path = job.destination_path,
        updated_at = clock_timestamp()
      where image_path = job.source_path;
    end if;
  elsif job.bucket_id = 'restaurant-images' then
    retained_reference := exists (
      select 1 from public.published_restaurants
      where cover_image_path = job.source_path
    );
    if retained_reference then
      update public.restaurant_revisions
      set cover_image_path = job.destination_path,
          updated_at = clock_timestamp()
      where cover_image_path = job.source_path;
      update public.published_restaurants
      set cover_image_path = job.destination_path,
          updated_at = clock_timestamp()
      where cover_image_path = job.source_path;
    end if;
  end if;

  if retained_reference then
    update private.storage_cleanup_jobs
    set stage = 'rehome_remove', updated_at = clock_timestamp()
    where id = job.id;
    insert into public.audit_events (
      actor_id, action, target_type, target_id, metadata
    ) values (
      null, 'storage.rehome_activated', 'storage_cleanup', job.id,
      jsonb_build_object('bucket_id', job.bucket_id)
    );
  else
    update private.storage_cleanup_jobs
    set stage = 'rehome_discard', updated_at = clock_timestamp()
    where id = job.id;
  end if;
  return retained_reference;
end;
$$;

create or replace function public.complete_storage_cleanup_job(
  p_job_id uuid,
  p_lock_token uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, private, storage
as $$
declare job private.storage_cleanup_jobs;
begin
  if coalesce(auth.role(), '') <> 'service_role'
      and current_user not in ('postgres', 'supabase_admin') then
    raise exception using errcode = '42501', message = 'Service role required';
  end if;
  select * into job from private.storage_cleanup_jobs
  where id = p_job_id and lock_token = p_lock_token and status = 'processing'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Claimed cleanup job not found';
  end if;
  if exists (
    select 1 from storage.objects object
    where object.bucket_id = job.bucket_id and object.name = job.source_path
  ) then
    raise exception using errcode = '22023', message = 'Source object still exists';
  end if;
  if job.action = 'rehome' then
    if job.stage = 'rehome_remove' and not exists (
      select 1 from storage.objects object
      where object.bucket_id = job.bucket_id
        and object.name = job.destination_path
    ) then
      raise exception using errcode = '22023', message = 'Retained object is missing';
    elsif job.stage = 'rehome_discard' and exists (
      select 1 from storage.objects object
      where object.bucket_id = job.bucket_id
        and object.name = job.destination_path
    ) then
      raise exception using errcode = '22023', message = 'Unused retained copy still exists';
    end if;
  end if;

  update private.storage_cleanup_jobs
  set status = 'completed', completed_at = clock_timestamp(),
      locked_at = null, lock_token = null, updated_at = clock_timestamp()
  where id = job.id;
end;
$$;

create or replace function public.fail_storage_cleanup_job(
  p_job_id uuid,
  p_lock_token uuid,
  p_error text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
declare attempts integer;
begin
  if coalesce(auth.role(), '') <> 'service_role'
      and current_user not in ('postgres', 'supabase_admin') then
    raise exception using errcode = '42501', message = 'Service role required';
  end if;
  if char_length(btrim(coalesce(p_error, ''))) < 3 then
    raise exception using errcode = '22023', message = 'Cleanup failure detail required';
  end if;

  select attempt_count into attempts
  from private.storage_cleanup_jobs
  where id = p_job_id and lock_token = p_lock_token and status = 'processing'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Claimed cleanup job not found';
  end if;

  update private.storage_cleanup_jobs
  set status = 'failed', locked_at = null, lock_token = null,
      last_error = left(btrim(p_error), 1000),
      next_attempt_at = clock_timestamp()
        + make_interval(secs => 60 * (2 ^ least(attempts, 8))::integer),
      updated_at = clock_timestamp()
  where id = p_job_id;
end;
$$;

drop policy avatar_delete_own on storage.objects;
create policy avatar_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and owner_id = auth.uid()::text
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.can_use_protected_features()
  );

drop policy spot_image_delete_owner on storage.objects;
create policy spot_image_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'spot-images'
    and owner_id = auth.uid()::text
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.can_use_protected_features()
  );

drop policy spot_image_select_owner_admin on storage.objects;
create policy spot_image_select_owner_admin
  on storage.objects for select to authenticated
  using (
    bucket_id = 'spot-images'
    and (
      (
        owner_id = auth.uid()::text
        and (storage.foldername(name))[1] = auth.uid()::text
        and private.can_use_protected_features()
      )
      or private.is_admin()
    )
  );

drop policy restaurant_image_delete_owner on storage.objects;
create policy restaurant_image_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'restaurant-images'
    and owner_id = auth.uid()::text
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.can_use_protected_features()
    and private.current_role(auth.uid()) = 'influencer'
  );

drop policy restaurant_image_select_owner_admin on storage.objects;
create policy restaurant_image_select_owner_admin
  on storage.objects for select to authenticated
  using (
    bucket_id = 'restaurant-images'
    and (
      (
        owner_id = auth.uid()::text
        and (storage.foldername(name))[1] = auth.uid()::text
        and private.can_use_protected_features()
        and private.current_role(auth.uid()) = 'influencer'
      )
      or private.is_admin()
    )
  );

create or replace function public.update_my_avatar(new_avatar_path text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private, storage
as $$
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot update an avatar';
  end if;
  if new_avatar_path !~ ('^' || auth.uid()::text || '/avatar\.(jpg|png|webp)$')
      or not exists (
        select 1 from storage.objects object
        where object.bucket_id = 'avatars'
          and object.name = new_avatar_path
          and object.owner_id = auth.uid()::text
      ) then
    raise exception using errcode = '22023', message = 'Uploaded avatar not found';
  end if;

  update public.profiles
  set avatar_path = new_avatar_path, updated_at = clock_timestamp()
  where id = auth.uid();
end;
$$;

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
    perform private.enqueue_account_storage_cleanup(due.user_id);

    -- Unknown buckets deliberately block deletion for operator review. Known
    -- objects are handled by the API worker; metadata is never deleted here.
    if exists (
      select 1 from storage.objects object
      where object.owner_id = due.user_id::text
    ) or exists (
      select 1 from private.storage_cleanup_jobs job
      where job.owner_id = due.user_id and job.status <> 'completed'
    ) then
      continue;
    end if;

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

    insert into public.audit_events (
      actor_id, action, target_type, target_id, metadata
    ) values (
      null, 'account.deletion_finalized', 'account', due.user_id,
      jsonb_build_object('request_id', due.id)
    );
    delete from private.storage_cleanup_jobs
    where owner_id = due.user_id and status = 'completed';
    delete from auth.users where id = due.user_id;
    completed := completed + 1;
  end loop;
  return completed;
end;
$$;

revoke all on function public.claim_storage_cleanup_jobs(integer) from public;
revoke all on function public.activate_storage_rehome_job(uuid,uuid) from public;
revoke all on function public.complete_storage_cleanup_job(uuid,uuid) from public;
revoke all on function public.fail_storage_cleanup_job(uuid,uuid,text) from public;
revoke all on function public.update_my_avatar(text) from public;
revoke all on function public.finalize_due_account_deletions() from public;

grant execute on function public.claim_storage_cleanup_jobs(integer)
  to service_role;
grant execute on function public.activate_storage_rehome_job(uuid,uuid)
  to service_role;
grant execute on function public.complete_storage_cleanup_job(uuid,uuid)
  to service_role;
grant execute on function public.fail_storage_cleanup_job(uuid,uuid,text)
  to service_role;
grant execute on function public.update_my_avatar(text) to authenticated;
grant execute on function public.finalize_due_account_deletions()
  to service_role;

commit;
