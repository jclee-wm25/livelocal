begin;

create table public.user_ugc_rule_acceptances (
  user_id uuid references auth.users(id) on delete cascade,
  rule_version text not null,
  accepted_at timestamptz not null default clock_timestamp(),
  primary key (user_id, rule_version)
);

alter table public.user_ugc_rule_acceptances enable row level security;
revoke all on table public.user_ugc_rule_acceptances from anon, authenticated;
-- No explicit policies created; writes happen exclusively via SECURITY DEFINER.

insert into public.app_settings (key, value) values
  ('current_ugc_rule_version', '"2026-08"'::jsonb),
  ('banned_words', '[]'::jsonb)
on conflict (key) do nothing;

create or replace function public.accept_current_ugc_rules()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  current_v text;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  
  select value#>>'{}' into current_v 
  from public.app_settings 
  where key = 'current_ugc_rule_version';
  
  if current_v is null or trim(current_v) = '' then
    raise exception using errcode = 'P0001', message = 'Current UGC rule version is missing';
  end if;

  insert into public.user_ugc_rule_acceptances (user_id, rule_version)
  values (auth.uid(), current_v)
  on conflict (user_id, rule_version) do nothing;
end;
$$;

create or replace function private.assert_current_ugc_rules_accepted()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  current_v text;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  
  select value#>>'{}' into current_v 
  from public.app_settings 
  where key = 'current_ugc_rule_version';
  
  if current_v is null or trim(current_v) = '' then
    raise exception using errcode = 'P0001', message = 'Current UGC rule version is missing';
  end if;

  if not exists (
    select 1 
    from public.user_ugc_rule_acceptances 
    where user_id = auth.uid() and rule_version = current_v
  ) then
    raise exception using 
      errcode = 'P0001', 
      message = 'UGC_RULES_ACCEPTANCE_REQUIRED';
  end if;
end;
$$;

create or replace function private.assert_no_banned_words(p_text text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  banned_json jsonb;
  banned text[];
  word text;
  normalized_text text;
begin
  if p_text is null or trim(p_text) = '' then
    return;
  end if;

  select value into banned_json 
  from public.app_settings 
  where key = 'banned_words';

  if banned_json is null or jsonb_typeof(banned_json) <> 'array' or jsonb_array_length(banned_json) = 0 then
    return;
  end if;

  -- Convert JSONB array to text[]
  select array_agg(x) into banned from jsonb_array_elements_text(banned_json) x;
  
  -- Replace all punctuation with space (preserving letters of any language)
  -- then compress repeated whitespaces
  normalized_text := regexp_replace(
    regexp_replace(lower(p_text), '[[:punct:]]+', ' ', 'g'),
    '\s+', ' ', 'g'
  );

  foreach word in array banned
  loop
    -- match whole words using \y
    if normalized_text ~* ('\y' || regexp_replace(word, '([.*+?^${}()|\[\]\\])', '\\\1', 'g') || '\y') then
      raise exception using 
        errcode = '22023', 
        message = 'UGC_CONTENT_RESTRICTED';
    end if;
  end loop;
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

  -- CMP-02 ENFORCEMENT
  perform private.assert_current_ugc_rules_accepted();

  select spot_revision.* into revision
  from public.spot_revisions spot_revision
  join public.spots spot on spot.id = spot_revision.spot_id
  where spot_revision.id = p_revision_id
    and spot.owner_id = auth.uid()
    and spot.current_revision_id = spot_revision.id
  for update of spot_revision;

  if not found then
    raise exception using errcode = 'P0002', message = 'Draft not found';
  end if;
  if revision.status <> 'draft' then
    raise exception using errcode = '22023', message = 'Only a draft can be submitted';
  end if;
  if revision.image_path is null or revision.image_rights_confirmed_at is null then
    raise exception using
      errcode = '22023',
      message = 'Spot image and rights confirmation are required';
  end if;

  -- CMP-02 FILTERING
  perform private.assert_no_banned_words(revision.name);
  perform private.assert_no_banned_words(revision.description);
  perform private.assert_no_banned_words(revision.things_to_do);

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
    jsonb_build_object('revision_id', revision.id, 'image_rights_confirmed', true)
  );

  return jsonb_build_object(
    'spot_id', revision.spot_id,
    'revision_id', revision.id,
    'status', 'submitted'
  );
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

  -- CMP-02 ENFORCEMENT
  perform private.assert_current_ugc_rules_accepted();
  perform private.assert_no_banned_words(p_body);

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

revoke all on function public.accept_current_ugc_rules() from public;
grant execute on function public.accept_current_ugc_rules() to authenticated;
revoke all on function private.assert_current_ugc_rules_accepted() from public;
revoke all on function private.assert_no_banned_words(text) from public;

commit;
