begin;

alter table public.spot_revisions
  add column image_rights_confirmed_at timestamptz;

create or replace function public.confirm_spot_image_rights(p_revision_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if not private.can_use_protected_features() then
    raise exception using errcode = '42501', message = 'Account cannot confirm image rights';
  end if;

  update public.spot_revisions revision set
    image_rights_confirmed_at = clock_timestamp(),
    updated_at = clock_timestamp()
  from public.spots spot
  where revision.id = p_revision_id
    and revision.spot_id = spot.id
    and spot.owner_id = auth.uid()
    and spot.current_revision_id = revision.id
    and revision.status = 'draft'
    and revision.image_path is not null
    and exists (
      select 1
      from storage.objects object
      where object.bucket_id = 'spot-images'
        and object.name = revision.image_path
    );

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Owned draft with an uploaded image not found';
  end if;
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

revoke all on function public.confirm_spot_image_rights(uuid) from public;
grant execute on function public.confirm_spot_image_rights(uuid) to authenticated;

commit;
