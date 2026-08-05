begin;

create type public.influencer_application_status as enum (
  'draft', 'submitted', 'under_review', 'approved', 'rejected',
  'needs_information', 'withdrawn'
);
create type public.discount_status as enum (
  'draft', 'scheduled', 'active', 'paused', 'expired', 'revoked'
);

create table public.influencer_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text,
  social_platform text check (social_platform in ('tiktok', 'instagram')),
  profile_url text,
  follower_count integer check (follower_count >= 0),
  content_category text,
  application_message text,
  rules_agreed_at timestamptz,
  status public.influencer_application_status not null default 'draft',
  version integer not null default 1 check (version > 0),
  submitted_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create unique index influencer_applications_one_active
  on public.influencer_applications(user_id)
  where status in ('draft', 'submitted', 'under_review', 'needs_information');

create table public.influencer_application_decisions (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null
    references public.influencer_applications(id) on delete cascade,
  decision public.influencer_application_status not null
    check (decision in ('approved', 'rejected', 'needs_information')),
  reason text not null check (char_length(btrim(reason)) between 3 and 1000),
  actor_id uuid not null references auth.users(id) on delete restrict,
  application_version integer not null,
  created_at timestamptz not null default clock_timestamp(),
  unique (application_id, application_version)
);

create or replace function private.is_supported_social_url(
  p_url text,
  p_platform text default null
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select p_url ~* '^https://(www\\.)?(tiktok\\.com|instagram\\.com)(/|$)'
    and (
      p_platform is null
      or (p_platform = 'tiktok' and p_url ~* '^https://(www\\.)?tiktok\\.com(/|$)')
      or (p_platform = 'instagram' and p_url ~* '^https://(www\\.)?instagram\\.com(/|$)')
    );
$$;

revoke all on function private.is_supported_social_url(text, text) from public;

create or replace function public.save_influencer_application_draft(
  p_application_id uuid,
  p_display_name text,
  p_social_platform text,
  p_profile_url text,
  p_follower_count integer,
  p_content_category text,
  p_application_message text,
  p_agree_to_rules boolean,
  p_expected_version integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  saved public.influencer_applications;
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'tourist' then
    raise exception using errcode = '42501', message = 'Account cannot apply as a creator';
  end if;
  if p_social_platform is not null
      and p_social_platform not in ('tiktok', 'instagram') then
    raise exception using errcode = '22023', message = 'Unsupported social platform';
  end if;
  if nullif(btrim(p_profile_url), '') is not null
      and not private.is_supported_social_url(p_profile_url, p_social_platform) then
    raise exception using errcode = '22023', message = 'Unsupported social profile URL';
  end if;

  if p_application_id is null then
    insert into public.influencer_applications (
      user_id, display_name, social_platform, profile_url, follower_count,
      content_category, application_message, rules_agreed_at
    ) values (
      auth.uid(), nullif(btrim(p_display_name), ''), p_social_platform,
      nullif(btrim(p_profile_url), ''), p_follower_count,
      nullif(btrim(p_content_category), ''),
      nullif(btrim(p_application_message), ''),
      case when p_agree_to_rules then clock_timestamp() else null end
    ) returning * into saved;
  else
    update public.influencer_applications
    set display_name = nullif(btrim(p_display_name), ''),
        social_platform = p_social_platform,
        profile_url = nullif(btrim(p_profile_url), ''),
        follower_count = p_follower_count,
        content_category = nullif(btrim(p_content_category), ''),
        application_message = nullif(btrim(p_application_message), ''),
        rules_agreed_at = case
          when p_agree_to_rules then coalesce(rules_agreed_at, clock_timestamp())
          else null
        end,
        version = version + 1,
        updated_at = clock_timestamp()
    where id = p_application_id
      and user_id = auth.uid()
      and status in ('draft', 'needs_information')
      and version = p_expected_version
    returning * into saved;
    if not found then
      raise exception using errcode = '40001', message = 'Application changed concurrently';
    end if;
  end if;
  return to_jsonb(saved);
end;
$$;

create or replace function public.submit_influencer_application(
  p_application_id uuid,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  application public.influencer_applications;
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'tourist' then
    raise exception using errcode = '42501', message = 'Account cannot apply as a creator';
  end if;
  select * into application
  from public.influencer_applications
  where id = p_application_id and user_id = auth.uid()
  for update;
  if not found or application.status not in ('draft', 'needs_information') then
    raise exception using errcode = 'P0002', message = 'Application draft not found';
  end if;
  if application.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Application changed concurrently';
  end if;
  if char_length(btrim(coalesce(application.display_name, ''))) < 2
      or application.social_platform is null
      or not private.is_supported_social_url(
        application.profile_url, application.social_platform
      )
      or application.follower_count is null
      or char_length(btrim(coalesce(application.content_category, ''))) < 2
      or char_length(btrim(coalesce(application.application_message, ''))) < 20
      or application.rules_agreed_at is null then
    raise exception using errcode = '22023', message = 'Application is incomplete';
  end if;

  update public.influencer_applications
  set status = 'submitted', submitted_at = clock_timestamp(),
      version = version + 1, updated_at = clock_timestamp()
  where id = application.id returning * into application;
  return to_jsonb(application);
end;
$$;

create or replace function public.withdraw_influencer_application(
  p_application_id uuid,
  p_expected_version integer
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.influencer_applications
  set status = 'withdrawn', version = version + 1,
      updated_at = clock_timestamp()
  where id = p_application_id
    and user_id = auth.uid()
    and status in ('submitted', 'under_review', 'needs_information')
    and version = p_expected_version;
  if not found then
    raise exception using errcode = '40001', message = 'Application cannot be withdrawn';
  end if;
end;
$$;

create or replace function public.admin_decide_influencer_application(
  p_application_id uuid,
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
  application public.influencer_applications;
  next_version integer;
begin
  if not private.is_admin() then
    raise exception using errcode = '42501', message = 'Admin permission required';
  end if;
  if p_decision not in ('approved', 'rejected', 'needs_information')
      or char_length(btrim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'Invalid application decision';
  end if;
  select * into application from public.influencer_applications
  where id = p_application_id for update;
  if not found or application.status not in ('submitted', 'under_review') then
    raise exception using errcode = 'P0002', message = 'Application is not awaiting review';
  end if;
  if application.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Application changed concurrently';
  end if;
  next_version := p_expected_version + 1;

  update public.influencer_applications
  set status = p_decision::public.influencer_application_status,
      version = next_version,
      decided_at = case when p_decision in ('approved', 'rejected')
        then clock_timestamp() else null end,
      updated_at = clock_timestamp()
  where id = application.id;

  insert into public.influencer_application_decisions (
    application_id, decision, reason, actor_id, application_version
  ) values (
    application.id, p_decision::public.influencer_application_status,
    btrim(p_reason), auth.uid(), next_version
  );

  if p_decision = 'approved' then
    update public.user_roles
    set revoked_at = clock_timestamp(), revoked_by = auth.uid()
    where user_id = application.user_id and revoked_at is null;
    insert into public.user_roles (user_id, role, granted_by)
    values (application.user_id, 'influencer', auth.uid());
  end if;

  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason, metadata
  ) values (
    auth.uid(), 'admin.influencer_application_' || p_decision,
    'influencer_application', application.id, btrim(p_reason),
    jsonb_build_object('applicant_id', application.user_id, 'version', next_version)
  );
  return jsonb_build_object(
    'application_id', application.id, 'status', p_decision,
    'version', next_version
  );
end;
$$;

create table public.restaurants (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  current_revision_id uuid,
  approved_revision_id uuid,
  moderation_version integer not null default 1 check (moderation_version > 0),
  ownership_status text not null default 'creator_owned'
    check (ownership_status in ('creator_owned', 'unclaimed', 'platform_maintained')),
  created_at timestamptz not null default clock_timestamp(),
  archived_at timestamptz
);

create table public.restaurant_revisions (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  revision_number integer not null check (revision_number > 0),
  author_id uuid references auth.users(id) on delete set null,
  status public.content_revision_status not null default 'draft',
  name text not null check (char_length(btrim(name)) between 2 and 140),
  address text not null check (char_length(btrim(address)) between 5 and 300),
  state text not null check (char_length(btrim(state)) between 2 and 80),
  city text not null check (char_length(btrim(city)) between 2 and 100),
  cuisine_type text not null check (char_length(btrim(cuisine_type)) between 2 and 80),
  price_range text not null check (price_range in ('$', '$$', '$$$', '$$$$')),
  reviewed_dishes text not null
    check (char_length(btrim(reviewed_dishes)) between 3 and 1000),
  social_media_url text not null,
  cover_image_path text,
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  duplicate_override_reason text check (char_length(duplicate_override_reason) <= 500),
  submitted_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (restaurant_id, revision_number),
  constraint restaurant_revision_coordinates_pair check (
    (latitude is null and longitude is null)
    or (latitude is not null and longitude is not null)
  ),
  constraint restaurant_social_url_supported check (
    private.is_supported_social_url(social_media_url, null)
  )
);

alter table public.restaurants
  add constraint restaurants_current_revision_fk foreign key (current_revision_id)
    references public.restaurant_revisions(id) on delete set null,
  add constraint restaurants_approved_revision_fk foreign key (approved_revision_id)
    references public.restaurant_revisions(id) on delete set null;

create table public.restaurant_moderation_decisions (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  revision_id uuid not null references public.restaurant_revisions(id) on delete restrict,
  decision text not null check (decision in ('approved', 'rejected')),
  reason text not null check (char_length(btrim(reason)) between 3 and 1000),
  actor_id uuid not null references auth.users(id) on delete restrict,
  moderation_version integer not null,
  created_at timestamptz not null default clock_timestamp(),
  unique (restaurant_id, moderation_version)
);

create table public.published_restaurants (
  id uuid primary key references public.restaurants(id) on delete cascade,
  revision_id uuid not null unique references public.restaurant_revisions(id) on delete restrict,
  name text not null,
  address text not null,
  state text not null,
  city text not null,
  cuisine_type text not null,
  price_range text not null,
  reviewed_dishes text not null,
  social_media_url text not null,
  cover_image_path text,
  creator_display_name text,
  ownership_status text not null,
  latitude double precision,
  longitude double precision,
  rating_average numeric(3,2) not null default 0 check (rating_average between 0 and 5),
  review_count integer not null default 0 check (review_count >= 0),
  published_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create index published_restaurants_discovery
  on public.published_restaurants(state, city, cuisine_type, updated_at desc);

create or replace function private.probable_restaurant_duplicates(
  p_name text,
  p_address text,
  p_latitude double precision,
  p_longitude double precision,
  p_exclude_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public, private, extensions
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', pr.id, 'name', pr.name, 'address', pr.address,
    'city', pr.city, 'state', pr.state
  ) order by pr.name), '[]'::jsonb)
  from public.published_restaurants pr
  where (p_exclude_id is null or pr.id <> p_exclude_id)
    and (
      private.normalize_listing_text(pr.name) = private.normalize_listing_text(p_name)
      or private.normalize_listing_text(pr.address) = private.normalize_listing_text(p_address)
      or similarity(lower(pr.name), lower(p_name)) >= 0.72
    )
    and (
      p_latitude is null or p_longitude is null
      or pr.latitude is null or pr.longitude is null
      or (abs(pr.latitude - p_latitude) <= 0.01
        and abs(pr.longitude - p_longitude) <= 0.01)
    );
$$;

revoke all on function private.probable_restaurant_duplicates(
  text, text, double precision, double precision, uuid
) from public;

create or replace function public.create_restaurant_draft(
  p_name text,
  p_address text,
  p_state text,
  p_city text,
  p_cuisine_type text,
  p_price_range text,
  p_reviewed_dishes text,
  p_social_media_url text,
  p_cover_image_path text default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  created_id uuid;
  revision_id uuid;
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'influencer' then
    raise exception using errcode = '42501', message = 'Approved creator role required';
  end if;
  if not private.is_supported_social_url(p_social_media_url, null) then
    raise exception using errcode = '22023', message = 'Unsupported social URL';
  end if;
  if p_cover_image_path is not null
      and p_cover_image_path !~ ('^' || auth.uid()::text || '/[A-Za-z0-9_-]+\\.(jpg|png|webp)$') then
    raise exception using errcode = '22023', message = 'Invalid restaurant image path';
  end if;

  insert into public.restaurants(owner_id) values (auth.uid()) returning id into created_id;
  insert into public.restaurant_revisions (
    restaurant_id, revision_number, author_id, name, address, state, city,
    cuisine_type, price_range, reviewed_dishes, social_media_url,
    cover_image_path, latitude, longitude
  ) values (
    created_id, 1, auth.uid(), btrim(p_name), btrim(p_address), btrim(p_state),
    btrim(p_city), btrim(p_cuisine_type), p_price_range,
    btrim(p_reviewed_dishes), btrim(p_social_media_url), p_cover_image_path,
    p_latitude, p_longitude
  ) returning id into revision_id;
  update public.restaurants set current_revision_id = revision_id where id = created_id;
  return jsonb_build_object(
    'restaurant_id', created_id, 'revision_id', revision_id,
    'image_path', p_cover_image_path, 'status', 'draft',
    'probable_duplicates', private.probable_restaurant_duplicates(
      p_name, p_address, p_latitude, p_longitude, created_id
    )
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
set search_path = pg_catalog, public, private
as $$
declare
  revision public.restaurant_revisions;
  duplicates jsonb;
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'influencer' then
    raise exception using errcode = '42501', message = 'Approved creator role required';
  end if;
  select rr.* into revision
  from public.restaurant_revisions rr
  join public.restaurants r on r.id = rr.restaurant_id
  where rr.id = p_revision_id and r.owner_id = auth.uid()
    and r.current_revision_id = rr.id for update of rr;
  if not found or revision.status <> 'draft' then
    raise exception using errcode = 'P0002', message = 'Restaurant draft not found';
  end if;
  duplicates := private.probable_restaurant_duplicates(
    revision.name, revision.address, revision.latitude, revision.longitude,
    revision.restaurant_id
  );
  if jsonb_array_length(duplicates) > 0
      and char_length(btrim(coalesce(p_duplicate_override_reason, ''))) < 10 then
    raise exception using errcode = '23505',
      message = 'Probable duplicate requires justified override', detail = duplicates::text;
  end if;
  update public.restaurant_revisions
  set status = 'submitted', submitted_at = clock_timestamp(),
      duplicate_override_reason = nullif(btrim(p_duplicate_override_reason), ''),
      updated_at = clock_timestamp()
  where id = revision.id;
end;
$$;

create or replace function public.delete_restaurant_draft(p_revision_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare target_id uuid;
begin
  select r.id into target_id
  from public.restaurants r
  join public.restaurant_revisions rr on rr.id = r.current_revision_id
  where r.owner_id = auth.uid() and r.approved_revision_id is null
    and rr.id = p_revision_id and rr.status = 'draft'
  for update of r;
  if not found then raise exception using errcode = 'P0002', message = 'Draft not found'; end if;
  delete from public.restaurants where id = target_id;
end;
$$;

create or replace function public.admin_moderate_restaurant_revision(
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
  revision public.restaurant_revisions;
  entity public.restaurants;
  next_version integer;
  creator_name text;
begin
  if not private.is_admin() then raise exception using errcode = '42501', message = 'Admin permission required'; end if;
  if p_decision not in ('approved', 'rejected') or char_length(btrim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'Invalid restaurant decision';
  end if;
  select * into revision from public.restaurant_revisions where id = p_revision_id;
  if not found then raise exception using errcode = 'P0002', message = 'Revision not found'; end if;
  select * into entity from public.restaurants where id = revision.restaurant_id for update;
  if entity.moderation_version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Restaurant changed concurrently';
  end if;
  if entity.current_revision_id <> revision.id
      or revision.status not in ('submitted', 'under_review') then
    raise exception using errcode = '22023', message = 'Revision is not awaiting review';
  end if;
  next_version := p_expected_version + 1;
  update public.restaurants set
    moderation_version = next_version,
    approved_revision_id = case when p_decision = 'approved' then revision.id else approved_revision_id end
  where id = entity.id;
  if p_decision = 'approved' then
    if entity.approved_revision_id is not null then
      update public.restaurant_revisions set status = 'archived'
      where id = entity.approved_revision_id;
    end if;
    update public.restaurant_revisions
    set status = 'approved', decided_at = clock_timestamp(), updated_at = clock_timestamp()
    where id = revision.id;
    select display_name into creator_name from public.profiles where id = entity.owner_id;
    insert into public.published_restaurants (
      id, revision_id, name, address, state, city, cuisine_type, price_range,
      reviewed_dishes, social_media_url, cover_image_path,
      creator_display_name, ownership_status, latitude, longitude
    ) values (
      entity.id, revision.id, revision.name, revision.address, revision.state,
      revision.city, revision.cuisine_type, revision.price_range,
      revision.reviewed_dishes, revision.social_media_url,
      revision.cover_image_path, creator_name, entity.ownership_status,
      revision.latitude, revision.longitude
    ) on conflict (id) do update set
      revision_id = excluded.revision_id, name = excluded.name,
      address = excluded.address, state = excluded.state, city = excluded.city,
      cuisine_type = excluded.cuisine_type, price_range = excluded.price_range,
      reviewed_dishes = excluded.reviewed_dishes,
      social_media_url = excluded.social_media_url,
      cover_image_path = excluded.cover_image_path,
      creator_display_name = excluded.creator_display_name,
      ownership_status = excluded.ownership_status,
      latitude = excluded.latitude, longitude = excluded.longitude,
      updated_at = clock_timestamp();
  else
    update public.restaurant_revisions
    set status = 'rejected', decided_at = clock_timestamp(), updated_at = clock_timestamp()
    where id = revision.id;
  end if;
  insert into public.restaurant_moderation_decisions (
    restaurant_id, revision_id, decision, reason, actor_id, moderation_version
  ) values (
    entity.id, revision.id, p_decision, btrim(p_reason), auth.uid(), next_version
  );
  insert into public.audit_events (
    actor_id, action, target_type, target_id, reason, metadata
  ) values (
    auth.uid(), 'admin.restaurant_' || p_decision, 'restaurant', entity.id,
    btrim(p_reason), jsonb_build_object('revision_id', revision.id, 'version', next_version)
  );
  return jsonb_build_object('restaurant_id', entity.id, 'status', p_decision, 'version', next_version);
end;
$$;

create table public.discount_codes (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  owner_id uuid references auth.users(id) on delete set null,
  code text not null check (code ~ '^[A-Z0-9_-]{3,32}$'),
  description text not null check (char_length(btrim(description)) between 3 and 500),
  redemption_terms text not null check (char_length(btrim(redemption_terms)) between 3 and 1000),
  starts_at timestamptz not null,
  expires_at timestamptz not null,
  status public.discount_status not null default 'draft',
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint discount_time_order check (expires_at > starts_at),
  unique (restaurant_id, code)
);

create or replace function public.create_discount_draft(
  p_restaurant_id uuid,
  p_code text,
  p_description text,
  p_redemption_terms text,
  p_starts_at timestamptz,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare saved public.discount_codes;
begin
  if not private.can_use_protected_features()
      or private.current_role(auth.uid()) <> 'influencer'
      or not exists (
        select 1 from public.restaurants r
        where r.id = p_restaurant_id and r.owner_id = auth.uid()
          and r.approved_revision_id is not null and r.archived_at is null
      ) then
    raise exception using errcode = '42501', message = 'Approved owned restaurant required';
  end if;
  insert into public.discount_codes (
    restaurant_id, owner_id, code, description, redemption_terms,
    starts_at, expires_at
  ) values (
    p_restaurant_id, auth.uid(), upper(btrim(p_code)), btrim(p_description),
    btrim(p_redemption_terms), p_starts_at, p_expires_at
  ) returning * into saved;
  return to_jsonb(saved);
end;
$$;

create or replace function public.transition_discount(
  p_discount_id uuid,
  p_action text,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare saved public.discount_codes;
declare next_status public.discount_status;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot manage discounts';
  end if;
  select * into saved from public.discount_codes
  where id = p_discount_id and owner_id = auth.uid() for update;
  if not found then raise exception using errcode = 'P0002', message = 'Discount not found'; end if;
  if saved.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'Discount changed concurrently';
  end if;
  next_status := case
    when p_action = 'publish' and saved.status = 'draft' and saved.starts_at > clock_timestamp() then 'scheduled'
    when p_action = 'publish' and saved.status = 'draft' and saved.expires_at > clock_timestamp() then 'active'
    when p_action = 'pause' and saved.status in ('scheduled', 'active') then 'paused'
    when p_action = 'resume' and saved.status = 'paused' and saved.starts_at > clock_timestamp() then 'scheduled'
    when p_action = 'resume' and saved.status = 'paused' and saved.expires_at > clock_timestamp() then 'active'
    when p_action = 'revoke' and saved.status not in ('expired', 'revoked') then 'revoked'
    else null
  end;
  if next_status is null then
    raise exception using errcode = '22023', message = 'Invalid discount transition';
  end if;
  update public.discount_codes set status = next_status,
    version = version + 1, updated_at = clock_timestamp()
  where id = saved.id returning * into saved;
  insert into public.audit_events (
    actor_id, action, target_type, target_id, metadata
  ) values (
    auth.uid(), 'discount.' || p_action, 'discount', saved.id,
    jsonb_build_object('status', saved.status, 'version', saved.version)
  );
  return to_jsonb(saved);
end;
$$;

create or replace function public.list_active_discounts(
  p_restaurant_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', dc.id,
    'restaurant_id', dc.restaurant_id,
    'code', dc.code,
    'description', dc.description,
    'redemption_terms', dc.redemption_terms,
    'starts_at', dc.starts_at,
    'expires_at', dc.expires_at,
    'effective_status', 'active'
  ) order by dc.expires_at), '[]'::jsonb)
  from public.discount_codes dc
  join public.restaurants r on r.id = dc.restaurant_id
  where dc.status in ('scheduled', 'active')
    and dc.starts_at <= clock_timestamp()
    and dc.expires_at > clock_timestamp()
    and private.effective_account_status(dc.owner_id) = 'active'
    and r.approved_revision_id is not null
    and r.archived_at is null
    and (p_restaurant_id is null or dc.restaurant_id = p_restaurant_id);
$$;

create or replace function private.recalculate_target_rating(
  p_target_type text,
  p_target_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare calculated_average numeric(3,2);
declare calculated_count integer;
begin
  select coalesce(round(avg(rating)::numeric, 2), 0), count(*)::integer
  into calculated_average, calculated_count
  from public.reviews
  where target_type = p_target_type and target_id = p_target_id and status = 'published';
  if p_target_type = 'spot' then
    update public.published_spots set rating_average = calculated_average,
      review_count = calculated_count, updated_at = clock_timestamp()
    where id = p_target_id;
  elsif p_target_type = 'restaurant' then
    update public.published_restaurants set rating_average = calculated_average,
      review_count = calculated_count, updated_at = clock_timestamp()
    where id = p_target_id;
  end if;
end;
$$;

create or replace function public.upsert_review(
  p_target_type text, p_target_id uuid, p_rating integer, p_body text,
  p_expected_version integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare existing public.reviews;
declare saved public.reviews;
declare author_name text;
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot write reviews';
  end if;
  if (p_target_type = 'spot' and not exists (select 1 from public.published_spots where id = p_target_id))
      or (p_target_type = 'restaurant' and not exists (select 1 from public.published_restaurants where id = p_target_id))
      or p_target_type not in ('spot', 'restaurant') then
    raise exception using errcode = '23503', message = 'Review target is unavailable';
  end if;
  if p_rating not between 1 and 5 or char_length(btrim(p_body)) not between 3 and 2000 then
    raise exception using errcode = '22023', message = 'Invalid review';
  end if;
  select p.display_name into author_name
  from public.profiles p where p.id = auth.uid();
  select * into existing from public.reviews
  where user_id = auth.uid() and target_type = p_target_type
    and target_id = p_target_id and status = 'published' for update;
  if found then
    if p_expected_version is null or existing.version <> p_expected_version then
      raise exception using errcode = '40001', message = 'Review changed concurrently';
    end if;
    insert into public.review_edit_history (
      review_id, prior_rating, prior_body, prior_version, edited_by
    ) values (existing.id, existing.rating, existing.body, existing.version, auth.uid());
    update public.reviews set rating = p_rating, body = btrim(p_body),
      author_display_name = author_name, version = version + 1,
      updated_at = clock_timestamp()
    where id = existing.id returning * into saved;
  else
    if p_expected_version is not null then raise exception using errcode = 'P0002', message = 'Review not found'; end if;
    insert into public.reviews (
      user_id, target_type, target_id, rating, body, author_display_name
    ) values (auth.uid(), p_target_type, p_target_id, p_rating, btrim(p_body), author_name)
    returning * into saved;
  end if;
  insert into public.public_reviews (
    id, target_type, target_id, rating, body, author_display_name,
    version, created_at, updated_at
  ) values (
    saved.id, saved.target_type, saved.target_id, saved.rating, saved.body,
    saved.author_display_name, saved.version, saved.created_at, saved.updated_at
  ) on conflict (id) do update set rating = excluded.rating, body = excluded.body,
    author_display_name = excluded.author_display_name, version = excluded.version,
    updated_at = excluded.updated_at;
  perform private.recalculate_target_rating(p_target_type, p_target_id);
  return to_jsonb(saved) - 'user_id';
end;
$$;

alter table public.influencer_applications enable row level security;
alter table public.influencer_application_decisions enable row level security;
alter table public.restaurants enable row level security;
alter table public.restaurant_revisions enable row level security;
alter table public.restaurant_moderation_decisions enable row level security;
alter table public.published_restaurants enable row level security;
alter table public.discount_codes enable row level security;

create policy influencer_applications_owner on public.influencer_applications
  for select to authenticated using (user_id = auth.uid());
create policy influencer_applications_admin on public.influencer_applications
  for select to authenticated using (private.is_admin());
create policy influencer_decisions_owner on public.influencer_application_decisions
  for select to authenticated using (exists (
    select 1 from public.influencer_applications ia
    where ia.id = application_id and ia.user_id = auth.uid()
  ));
create policy influencer_decisions_admin on public.influencer_application_decisions
  for select to authenticated using (private.is_admin());
create policy restaurants_owner on public.restaurants for select to authenticated
  using (owner_id = auth.uid());
create policy restaurants_admin on public.restaurants for select to authenticated
  using (private.is_admin());
create policy restaurant_revisions_owner on public.restaurant_revisions
  for select to authenticated using (exists (
    select 1 from public.restaurants r where r.id = restaurant_id and r.owner_id = auth.uid()
  ));
create policy restaurant_revisions_admin on public.restaurant_revisions
  for select to authenticated using (private.is_admin());
create policy restaurant_decisions_owner on public.restaurant_moderation_decisions
  for select to authenticated using (exists (
    select 1 from public.restaurants r where r.id = restaurant_id and r.owner_id = auth.uid()
  ));
create policy restaurant_decisions_admin on public.restaurant_moderation_decisions
  for select to authenticated using (private.is_admin());
create policy published_restaurants_public on public.published_restaurants
  for select to anon, authenticated using (not private.is_content_hidden('restaurant', id));
create policy discounts_owner on public.discount_codes for select to authenticated
  using (owner_id = auth.uid());
create policy discounts_admin on public.discount_codes for select to authenticated
  using (private.is_admin());

revoke all on table public.influencer_applications from anon, authenticated;
revoke all on table public.influencer_application_decisions from anon, authenticated;
revoke all on table public.restaurants from anon, authenticated;
revoke all on table public.restaurant_revisions from anon, authenticated;
revoke all on table public.restaurant_moderation_decisions from anon, authenticated;
revoke all on table public.published_restaurants from anon, authenticated;
revoke all on table public.discount_codes from anon, authenticated;
grant select on table public.influencer_applications to authenticated;
grant select on table public.influencer_application_decisions to authenticated;
grant select on table public.restaurants to authenticated;
grant select on table public.restaurant_revisions to authenticated;
grant select on table public.restaurant_moderation_decisions to authenticated;
grant select on table public.published_restaurants to anon, authenticated;
grant select on table public.discount_codes to authenticated;
revoke all on function public.list_active_discounts(uuid) from public;
grant execute on function public.list_active_discounts(uuid) to anon, authenticated;

revoke all on function public.save_influencer_application_draft(uuid,text,text,text,integer,text,text,boolean,integer) from public;
revoke all on function public.submit_influencer_application(uuid,integer) from public;
revoke all on function public.withdraw_influencer_application(uuid,integer) from public;
revoke all on function public.admin_decide_influencer_application(uuid,text,text,integer) from public;
revoke all on function public.create_restaurant_draft(text,text,text,text,text,text,text,text,text,double precision,double precision) from public;
revoke all on function public.submit_restaurant_revision(uuid,text) from public;
revoke all on function public.delete_restaurant_draft(uuid) from public;
revoke all on function public.admin_moderate_restaurant_revision(uuid,text,text,integer) from public;
revoke all on function public.create_discount_draft(uuid,text,text,text,timestamptz,timestamptz) from public;
revoke all on function public.transition_discount(uuid,text,integer) from public;

grant execute on function public.save_influencer_application_draft(uuid,text,text,text,integer,text,text,boolean,integer) to authenticated;
grant execute on function public.submit_influencer_application(uuid,integer) to authenticated;
grant execute on function public.withdraw_influencer_application(uuid,integer) to authenticated;
grant execute on function public.admin_decide_influencer_application(uuid,text,text,integer) to authenticated;
grant execute on function public.create_restaurant_draft(text,text,text,text,text,text,text,text,text,double precision,double precision) to authenticated;
grant execute on function public.submit_restaurant_revision(uuid,text) to authenticated;
grant execute on function public.delete_restaurant_draft(uuid) to authenticated;
grant execute on function public.admin_moderate_restaurant_revision(uuid,text,text,integer) to authenticated;
grant execute on function public.create_discount_draft(uuid,text,text,text,timestamptz,timestamptz) to authenticated;
grant execute on function public.transition_discount(uuid,text,integer) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('restaurant-images', 'restaurant-images', false, 8388608,
  array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
create policy restaurant_image_insert_owner on storage.objects for insert to authenticated
  with check (bucket_id = 'restaurant-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and private.can_use_protected_features()
    and private.current_role(auth.uid()) = 'influencer');
create policy restaurant_image_select_published on storage.objects for select to anon, authenticated
  using (bucket_id = 'restaurant-images' and exists (
    select 1 from public.published_restaurants pr where pr.cover_image_path = name
  ));
create policy restaurant_image_select_owner_admin on storage.objects for select to authenticated
  using (bucket_id = 'restaurant-images' and (
    (storage.foldername(name))[1] = auth.uid()::text or private.is_admin()
  ));
create policy restaurant_image_delete_owner on storage.objects for delete to authenticated
  using (bucket_id = 'restaurant-images'
    and (storage.foldername(name))[1] = auth.uid()::text);

commit;
